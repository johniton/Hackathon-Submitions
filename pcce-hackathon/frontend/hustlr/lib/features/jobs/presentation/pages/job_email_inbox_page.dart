import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:hustlr/core/theme/app_colors.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:hustlr/config.dart';

class JobEmailInboxPage extends StatefulWidget {
  const JobEmailInboxPage({super.key});
  @override
  State<JobEmailInboxPage> createState() => _JobEmailInboxPageState();
}

class _JobEmailInboxPageState extends State<JobEmailInboxPage> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  bool _gmailConnected = true;
  bool _outlookConnected = false;
  int _selectedFilter = 0;
  bool _isSummarizing = false;
  String? _aiSummary;
  final _emailCtrl = TextEditingController();
  bool _isScraping = false;
  String? _emailAnalysis;

  @override
  void initState() { super.initState(); _tabCtrl = TabController(length: 5, vsync: this); }
  @override
  void dispose() { _tabCtrl.dispose(); super.dispose(); }

  static const _emails = [
    {'company': 'Google', 'subject': 'Interview Invitation — Software Engineer L4', 'preview': 'Dear Alex, We are delighted to invite you for a technical interview scheduled for May 20th...', 'time': '10:30 AM', 'date': 'Today', 'type': 'interview', 'unread': true, 'deadline': 'May 20, 2:00 PM', 'logo': 'G'},
    {'company': 'Razorpay', 'subject': 'Your Application Status Update', 'preview': 'Hi Alex, Thank you for your interest. After careful consideration, we regret to inform...', 'time': '9:15 AM', 'date': 'Today', 'type': 'rejection', 'unread': true, 'deadline': '', 'logo': 'R'},
    {'company': 'CRED', 'subject': 'Offer Letter — Flutter Developer', 'preview': 'Congratulations! We are pleased to extend an offer for the position of Flutter Developer...', 'time': '6:00 PM', 'date': 'Yesterday', 'type': 'offer', 'unread': false, 'deadline': 'Accept by May 18', 'logo': 'C'},
    {'company': 'Meesho', 'subject': 'Complete Your Coding Assessment', 'preview': 'Please complete the HackerRank assessment within the next 48 hours...', 'time': '2:30 PM', 'date': 'Yesterday', 'type': 'assessment', 'unread': false, 'deadline': 'Due May 16', 'logo': 'M'},
    {'company': 'Flipkart', 'subject': 'Application Received — SDE-2', 'preview': 'Thank you for applying to Software Development Engineer II at Flipkart...', 'time': '11:00 AM', 'date': 'May 12', 'type': 'confirmation', 'unread': false, 'deadline': '', 'logo': 'F'},
    {'company': 'PhonePe', 'subject': 'Interview Scheduled — System Design', 'preview': 'Your next round: Date: May 22 at 3 PM, Mode: Video call...', 'time': '4:45 PM', 'date': 'May 11', 'type': 'interview', 'unread': false, 'deadline': 'May 22, 3:00 PM', 'logo': 'P'},
  ];

  static const _filterLabels = ['All', 'Interviews', 'Offers', 'Rejections', 'Applied'];
  static const _filterTypes = ['all', 'interview', 'offer', 'rejection', 'confirmation'];

  List<Map<String, dynamic>> get _filtered {
    if (_selectedFilter == 0) return _emails;
    return _emails.where((e) => e['type'] == _filterTypes[_selectedFilter]).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final unread = _emails.where((e) => e['unread'] == true).length;
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(backgroundColor: AppColors.backgroundLight, title: const Text('Job Inbox'), actions: [
        GestureDetector(onTap: _showConnectDialog, child: Container(
          margin: const EdgeInsets.only(right: 16), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
          child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(LucideIcons.link, size: 14, color: AppColors.primary), SizedBox(width: 4), Text('Connect', style: TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.bold))]),
        )),
      ]),
      body: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Hero
        Container(width: double.infinity, padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(22), boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 8))]),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('📬 Unified Job Inbox', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)), SizedBox(height: 4), Text('AI-sorted emails from your accounts', style: TextStyle(color: Colors.white70, fontSize: 12))])), Icon(LucideIcons.sparkles, color: Colors.white, size: 22)]),
            const SizedBox(height: 12),
            Row(children: [_heroBadge('📩 $unread new'), const SizedBox(width: 8), _heroBadge('📅 2 interviews'), const SizedBox(width: 8), _heroBadge('🎉 1 offer')]),
            const SizedBox(height: 12),
            Row(children: [_accountChip('Gmail', '✉️', _gmailConnected, AppColors.error), const SizedBox(width: 8), _accountChip('Outlook', '📧', _outlookConnected, AppColors.info)]),
          ]),
        ),
        const SizedBox(height: 14),

        // ── Paste & Analyze Email ────────────────────────────────
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: AppColors.surfaceLight, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE8DDD2))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Row(children: [Icon(LucideIcons.mailSearch, size: 16, color: AppColors.primary), SizedBox(width: 8), Text('Paste & Analyze Job Emails', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimaryLight))]),
            const SizedBox(height: 4),
            const Text('Paste any job email and AI will extract actions, deadlines & next steps', style: TextStyle(color: AppColors.textSecondaryLight, fontSize: 11)),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(color: AppColors.backgroundLight, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE8DDD2))),
              child: TextField(controller: _emailCtrl, maxLines: 5, decoration: const InputDecoration(border: InputBorder.none, hintText: 'Paste your job email here…\n\ne.g. "Dear candidate, We are pleased to invite you for a technical interview…"', hintStyle: TextStyle(fontSize: 12, color: AppColors.textSecondaryLight), isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 12))),
            ),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: _isScraping ? null : _analyzeEmail,
              child: Container(
                width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 8)]),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  _isScraping ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(LucideIcons.sparkles, size: 18, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(_isScraping ? 'Analyzing…' : 'Analyze with Gemini AI', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                ]),
              ),
            ),
            if (_emailAnalysis != null) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity, padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: const Color(0xFF7C3AED).withValues(alpha: 0.06), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFF7C3AED).withValues(alpha: 0.2))),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Row(children: [Icon(LucideIcons.sparkles, size: 14, color: Color(0xFF7C3AED)), SizedBox(width: 6), Text('AI Email Analysis', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF7C3AED)))]),
                  const SizedBox(height: 8),
                  MarkdownBody(
                    data: _emailAnalysis!,
                    styleSheet: MarkdownStyleSheet(
                      p: const TextStyle(fontSize: 13, height: 1.6, color: AppColors.textPrimaryLight),
                      listBullet: const TextStyle(color: Color(0xFF7C3AED)),
                    ),
                  ),
                ]),
              ),
            ],
          ]),
        ),
        const SizedBox(height: 14),


        // AI Summary Button
        GestureDetector(
          onTap: _isSummarizing ? null : _generateAISummary,
          child: Container(padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF7C3AED), Color(0xFFA78BFA)]), borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: const Color(0xFF7C3AED).withValues(alpha: 0.25), blurRadius: 12, offset: const Offset(0, 4))]),
            child: Row(children: [
              _isSummarizing ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(LucideIcons.sparkles, color: Colors.white, size: 18),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_isSummarizing ? 'Gemini analyzing...' : '✨ AI Email Report', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
                const Text('Gemini summarizes all emails into an actionable report', style: TextStyle(color: Colors.white70, fontSize: 11)),
              ])),
            ]),
          ),
        ),
        if (_aiSummary != null) ...[
          const SizedBox(height: 10),
          Container(width: double.infinity, padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: const Color(0xFF7C3AED).withValues(alpha: 0.06), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFF7C3AED).withValues(alpha: 0.2))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Row(children: [Icon(LucideIcons.sparkles, size: 14, color: Color(0xFF7C3AED)), SizedBox(width: 6), Text('Gemini Report', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF7C3AED)))]),
              const SizedBox(height: 8),
              MarkdownBody(
                data: _aiSummary!,
                styleSheet: MarkdownStyleSheet(
                  p: const TextStyle(fontSize: 13, height: 1.5, color: AppColors.textPrimaryLight),
                  listBullet: const TextStyle(color: Color(0xFF7C3AED)),
                ),
              ),
            ]),
          ),
        ],
        const SizedBox(height: 14),

        // Digest
        Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.warning.withValues(alpha: 0.25))),
          child: const Row(children: [Icon(LucideIcons.clock, color: AppColors.warning, size: 18), SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Morning Digest · 8 AM', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.textPrimaryLight)), Text('2 interviews, 1 deadline today', style: TextStyle(color: AppColors.textSecondaryLight, fontSize: 11))]))])),
        const SizedBox(height: 14),

        // Filters
        SizedBox(height: 34, child: ListView.separated(scrollDirection: Axis.horizontal, itemCount: _filterLabels.length, separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final sel = _selectedFilter == i;
            final count = i == 0 ? _emails.length : _emails.where((e) => e['type'] == _filterTypes[i]).length;
            return GestureDetector(onTap: () => setState(() => _selectedFilter = i),
              child: AnimatedContainer(duration: const Duration(milliseconds: 200), padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(gradient: sel ? AppColors.primaryGradient : null, color: sel ? null : AppColors.surfaceLight, borderRadius: BorderRadius.circular(18), border: sel ? null : Border.all(color: const Color(0xFFE8DDD2))),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(_filterLabels[i], style: TextStyle(color: sel ? Colors.white : AppColors.textSecondaryLight, fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(width: 5),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1), decoration: BoxDecoration(color: sel ? Colors.white24 : const Color(0xFFE8DDD2), borderRadius: BorderRadius.circular(8)),
                    child: Text('$count', style: TextStyle(color: sel ? Colors.white : AppColors.textSecondaryLight, fontSize: 10, fontWeight: FontWeight.bold))),
                ]),
              ),
            );
          },
        )),
        const SizedBox(height: 14),

        // Emails
        ...filtered.map((e) => Padding(padding: const EdgeInsets.only(bottom: 10), child: _emailCard(e))),
        if (filtered.isEmpty) const Center(child: Padding(padding: EdgeInsets.all(40), child: Text('📭 No emails', style: TextStyle(fontSize: 16)))),
      ])),
    );
  }

  Widget _emailCard(Map<String, dynamic> email) {
    final type = email['type'] as String;
    final unread = email['unread'] as bool;
    final deadline = email['deadline'] as String;
    final tc = type == 'interview' ? AppColors.warning : type == 'offer' ? AppColors.success : type == 'rejection' ? AppColors.error : type == 'assessment' ? AppColors.accentPurple : AppColors.primary;
    final tl = type == 'interview' ? '📅 Interview' : type == 'offer' ? '🎉 Offer' : type == 'rejection' ? '❌ Rejected' : type == 'assessment' ? '💻 Assessment' : '✅ Confirmed';

    return GestureDetector(onTap: () => _showEmailDetail(email),
      child: Container(padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: unread ? AppColors.primary.withValues(alpha: 0.04) : AppColors.surfaceLight, borderRadius: BorderRadius.circular(14), border: Border.all(color: unread ? AppColors.primary.withValues(alpha: 0.2) : const Color(0xFFE8DDD2))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(width: 40, height: 40, decoration: BoxDecoration(color: tc.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
              child: Center(child: Text(email['logo'] as String, style: TextStyle(color: tc, fontWeight: FontWeight.w800, fontSize: 16)))),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [Expanded(child: Text(email['company'] as String, style: TextStyle(fontWeight: unread ? FontWeight.w800 : FontWeight.w600, fontSize: 13))), Text(email['time'] as String, style: const TextStyle(color: AppColors.textSecondaryLight, fontSize: 11))]),
              Text(email['subject'] as String, style: const TextStyle(fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
            ])),
            if (unread) Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle)),
          ]),
          const SizedBox(height: 8),
          Text(email['preview'] as String, style: const TextStyle(color: AppColors.textSecondaryLight, fontSize: 11, height: 1.4), maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 8),
          Row(children: [
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: tc.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
              child: Text(tl, style: TextStyle(color: tc, fontSize: 10, fontWeight: FontWeight.bold))),
            if (deadline.isNotEmpty) ...[const SizedBox(width: 8),
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [const Icon(LucideIcons.clock, size: 10, color: AppColors.warning), const SizedBox(width: 3), Text(deadline, style: const TextStyle(color: AppColors.warning, fontSize: 10, fontWeight: FontWeight.w600))]))],
            const Spacer(), const Icon(LucideIcons.chevronRight, size: 14, color: AppColors.textSecondaryLight),
          ]),
        ]),
      ),
    );
  }

  void _showEmailDetail(Map<String, dynamic> email) {
    final deadline = email['deadline'] as String;
    showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: AppColors.backgroundLight,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => DraggableScrollableSheet(expand: false, initialChildSize: 0.7, maxChildSize: 0.9,
        builder: (_, ctrl) => SingleChildScrollView(controller: ctrl, padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFFD8CFC4), borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            Text(email['company'] as String, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text('${email['date']} at ${email['time']}', style: const TextStyle(color: AppColors.textSecondaryLight, fontSize: 12)),
            const SizedBox(height: 12),
            Text(email['subject'] as String, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
            const SizedBox(height: 14), const Divider(color: Color(0xFFEBE3D8)), const SizedBox(height: 14),
            Text(email['preview'] as String, style: const TextStyle(fontSize: 14, height: 1.6)),
            const SizedBox(height: 20),
            if (deadline.isNotEmpty) ...[
              Container(width: double.infinity, padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.warning.withValues(alpha: 0.25))),
                child: Row(children: [
                  const Icon(LucideIcons.calendar, color: AppColors.warning, size: 18), const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Deadline', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)), Text(deadline, style: const TextStyle(color: AppColors.warning, fontSize: 12))])),
                  GestureDetector(onTap: () { Navigator.pop(context); _addToCalendar(email); },
                    child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: AppColors.warning, borderRadius: BorderRadius.circular(8)),
                      child: const Text('Add to Calendar', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)))),
                ])),
              const SizedBox(height: 14),
            ],
            Row(children: [
              Expanded(child: ElevatedButton.icon(onPressed: () { Navigator.pop(context); _replyViaEmail(email); }, icon: const Icon(LucideIcons.reply, size: 16), label: const Text('Reply'))),
              const SizedBox(width: 10),
              GestureDetector(onTap: () { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Archived!'), backgroundColor: AppColors.success)); },
                child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE8DDD2)), borderRadius: BorderRadius.circular(14)), child: const Icon(LucideIcons.archive, size: 18, color: AppColors.textSecondaryLight))),
              const SizedBox(width: 8),
              GestureDetector(onTap: () { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Deleted!'), backgroundColor: AppColors.error)); },
                child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE8DDD2)), borderRadius: BorderRadius.circular(14)), child: const Icon(LucideIcons.trash2, size: 18, color: AppColors.error))),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _heroBadge(String t) => Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10)), child: Text(t, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)));
  Widget _accountChip(String n, String e, bool c, Color cl) => Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: c ? cl.withValues(alpha: 0.15) : Colors.white24, borderRadius: BorderRadius.circular(10), border: Border.all(color: c ? cl.withValues(alpha: 0.3) : Colors.white30)), child: Row(mainAxisSize: MainAxisSize.min, children: [Text(e, style: const TextStyle(fontSize: 14)), const SizedBox(width: 6), Text(n, style: TextStyle(color: c ? Colors.white : Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)), const SizedBox(width: 4), Icon(c ? LucideIcons.check : LucideIcons.plus, size: 12, color: c ? Colors.white : Colors.white54)]));

  void _showConnectDialog() {
    showModalBottomSheet(context: context, backgroundColor: AppColors.backgroundLight,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('Connect Email Accounts', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 20),
        _connectRow('Gmail', '✉️', _gmailConnected, AppColors.error, () { setState(() => _gmailConnected = !_gmailConnected); Navigator.pop(context); }),
        const SizedBox(height: 10),
        _connectRow('Outlook', '📧', _outlookConnected, AppColors.info, () { setState(() => _outlookConnected = !_outlookConnected); Navigator.pop(context); }),
      ])),
    );
  }

  Widget _connectRow(String n, String e, bool c, Color cl, VoidCallback onTap) => GestureDetector(onTap: onTap, child: Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: c ? cl.withValues(alpha: 0.06) : AppColors.surfaceLight, borderRadius: BorderRadius.circular(16), border: Border.all(color: c ? cl.withValues(alpha: 0.3) : const Color(0xFFE8DDD2))),
    child: Row(children: [Text(e, style: const TextStyle(fontSize: 28)), const SizedBox(width: 14), Expanded(child: Text(n, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
      Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7), decoration: BoxDecoration(color: c ? cl : AppColors.primary, borderRadius: BorderRadius.circular(10)),
        child: Text(c ? 'Connected ✓' : 'Connect', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)))])));

  Color _tagColor(String type) {
    switch (type) {
      case 'Interview': return AppColors.warning;
      case 'Offer': return AppColors.success;
      case 'Rejection': return AppColors.error;
      case 'Assessment': return AppColors.accentPurple;
      default: return AppColors.primary;
    }
  }

  Future<void> _analyzeEmail() async {
    if (_emailCtrl.text.trim().isEmpty) return;
    setState(() { _isScraping = true; _emailAnalysis = null; });
    try {
      final resp = await http.post(
        Uri.parse('${AppConfig.baseUrl}/ai-tools/email/analyze'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email_content': _emailCtrl.text}),
      );
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        setState(() => _emailAnalysis = data['analysis'] as String);
      } else {
        setState(() => _emailAnalysis = 'Error: ${resp.statusCode}');
      }
    } catch (e) { setState(() => _emailAnalysis = 'Error: $e'); }
    finally { setState(() => _isScraping = false); }
  }

  Future<void> _generateAISummary() async {
    setState(() { _isSummarizing = true; _aiSummary = null; });
    try {
      final allEmails = _emails.map((e) => '• ${e['company']}: ${e['subject']} [${e['type']}] — Deadline: ${(e['deadline'] as String).isEmpty ? 'none' : e['deadline']}').join('\n');
      final resp = await http.post(
        Uri.parse('${AppConfig.baseUrl}/ai-tools/email/summary'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'emails_content': allEmails}),
      );
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        setState(() => _aiSummary = data['summary'] as String);
      } else {
        setState(() => _aiSummary = 'Error: ${resp.statusCode}');
      }
    } catch (e) {
      setState(() => _aiSummary = 'Error: $e');
    } finally {
      setState(() => _isSummarizing = false);
    }
  }

  void _replyViaEmail(Map<String, dynamic> email) {
    final subject = Uri.encodeComponent('Re: ${email['subject']}');
    final body = Uri.encodeComponent('Hi ${email['company']} team,\n\nThank you for your email.\n\n');
    launchUrl(Uri.parse('mailto:?subject=$subject&body=$body'), mode: LaunchMode.externalApplication);
  }

  void _addToCalendar(Map<String, dynamic> email) {
    final title = Uri.encodeComponent('${email['company']} - ${email['subject']}');
    launchUrl(Uri.parse('https://calendar.google.com/calendar/render?action=TEMPLATE&text=$title&details=Job+application+event'), mode: LaunchMode.externalApplication);
  }
}
