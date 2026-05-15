import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hustlr/core/theme/app_colors.dart';
import 'package:hustlr/core/services/session_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'job_ai_screening_page.dart';

class JobDetailPage extends StatefulWidget {
  final Map<String, dynamic> job;
  const JobDetailPage({super.key, required this.job});

  @override
  State<JobDetailPage> createState() => _JobDetailPageState();
}

class _JobDetailPageState extends State<JobDetailPage> {
  final _db = Supabase.instance.client;
  bool _applying = false;
  bool _alreadyApplied = false;
  String? _existingAppId;
  String? _existingAppStatus;
  DateTime? _scheduledAt;
  String? _meetLink;

  @override
  void initState() {
    super.initState();
    _checkAlreadyApplied();
  }

  Future<void> _checkAlreadyApplied() async {
    final userId = await SessionService.getId();
    if (userId == null) return;
    final res = await _db
        .from('job_applications')
        .select('id, status, interview_scheduled_at, interview_meet_link')
        .eq('job_id', widget.job['id'])
        .eq('user_id', userId)
        .maybeSingle();
    if (mounted) {
      setState(() {
        _alreadyApplied = res != null;
        if (res != null) {
          _existingAppId = res['id'];
          _existingAppStatus = res['status'];
          if (res['interview_scheduled_at'] != null) {
            _scheduledAt = DateTime.parse(res['interview_scheduled_at']);
          }
          _meetLink = res['interview_meet_link'];
        }
      });
    }
  }

  Future<void> _apply() async {
    final userId = await SessionService.getId();
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please login first')));
      return;
    }

    setState(() => _applying = true);
    try {
      final aiEnabled = widget.job['ai_screening_enabled'] == true;

      // Check if we just need to resume
      if (_alreadyApplied && _existingAppStatus == 'ai_screening') {
        if (!mounted) return;
        Navigator.push(context, MaterialPageRoute(builder: (_) => JobAiScreeningPage(job: widget.job, applicationId: _existingAppId ?? '')));
        return;
      }

      await _db.from('job_applications').insert({
        'job_id': widget.job['id'],
        'user_id': userId,
        'status': 'applied',
      });

      if (!mounted) return;

      if (aiEnabled) {
        // Update status to screening and go take the AI interview
        final appRes = await _db.from('job_applications').select('id').eq('job_id', widget.job['id']).eq('user_id', userId).maybeSingle();
        await _db.from('job_applications').update({'status': 'ai_screening'}).eq('id', appRes?['id']);

        if (!mounted) return;
        Navigator.push(context, MaterialPageRoute(builder: (_) => JobAiScreeningPage(job: widget.job, applicationId: appRes?['id'] ?? '')));
      } else {
        setState(() => _alreadyApplied = true);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Application submitted!')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _applying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final job = widget.job;
    final aiEnabled = job['ai_screening_enabled'] == true;
    final skills = (job['required_skills'] as List?)?.cast<String>() ?? [];

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08)))),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(width: 38, height: 38, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(10)), child: const Icon(LucideIcons.arrowLeft, color: Colors.white70, size: 18)),
                  ),
                  const SizedBox(width: 12),
                  const Text('Job Details', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // Company badge
                  Row(children: [
                    Container(
                      width: 48, height: 48,
                      decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(14)),
                      child: const Icon(LucideIcons.building2, color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(job['title'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                        Text(job['companies']?['name'] ?? 'Company', style: TextStyle(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.w600)),
                      ]),
                    ),
                  ]),
                  const SizedBox(height: 16),

                  // Metadata row
                  Wrap(spacing: 10, runSpacing: 8, children: [
                    if (job['location'] != null) _metaChip(LucideIcons.mapPin, job['location']),
                    _metaChip(LucideIcons.briefcase, job['job_type'] ?? 'Full-Time'),
                    _metaChip(LucideIcons.barChart2, job['experience_level'] ?? 'Mid'),
                    if (job['salary_range'] != null) _metaChip(LucideIcons.indianRupee, job['salary_range']),
                  ]),
                  const SizedBox(height: 20),

                  // AI Screening Banner
                  if (aiEnabled) Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [AppColors.primary.withValues(alpha: 0.15), AppColors.accentPurple.withValues(alpha: 0.1)]),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                    ),
                    child: Row(children: [
                      const Icon(LucideIcons.bot, color: AppColors.primary, size: 20),
                      const SizedBox(width: 10),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('AI Interview Required', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                        Text('You must pass an AI screening interview (min score: ${job['ai_score_threshold'] ?? 60}) before being considered.',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12, height: 1.4)),
                      ])),
                    ]),
                  ),
                  const SizedBox(height: 20),

                  // Description
                  _sectionHeader('About this Role'),
                  const SizedBox(height: 10),
                  Text(job['description'] ?? '', style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 14, height: 1.6)),
                  const SizedBox(height: 20),

                  // Skills
                  if (skills.isNotEmpty) ...[
                    _sectionHeader('Required Skills'),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8, runSpacing: 8,
                      children: skills.map((s) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.primary.withValues(alpha: 0.3))),
                        child: Text(s, style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600)),
                      )).toList(),
                    ),
                  ],
                  const SizedBox(height: 40),
                ]),
              ),
            ),

            // Apply CTA
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.06)))),
              child: _alreadyApplied && _existingAppStatus != 'ai_screening'
                  ? Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: _existingAppStatus == 'scheduled' ? const Color(0xFF3B82F6).withOpacity(0.1) : Colors.white.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(16), border: _existingAppStatus == 'scheduled' ? Border.all(color: const Color(0xFF3B82F6).withOpacity(0.3)) : null),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center, 
                        children: [
                        if (_existingAppStatus == 'scheduled') ...[
                          const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Icon(LucideIcons.calendarCheck, color: Color(0xFF3B82F6), size: 18),
                            SizedBox(width: 10),
                            Text('Interview Scheduled', style: TextStyle(color: Color(0xFF3B82F6), fontWeight: FontWeight.bold, fontSize: 15)),
                          ]),
                          const SizedBox(height: 8),
                          if (_scheduledAt != null) Text('Date: ${_scheduledAt!.toLocal().toString().split('.')[0]}', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                          if (_meetLink != null) ...[
                            const SizedBox(height: 8),
                            GestureDetector(
                              onTap: () {
                                launchUrl(Uri.parse(_meetLink!));
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(color: const Color(0xFF3B82F6), borderRadius: BorderRadius.circular(8)),
                                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                                  Icon(LucideIcons.video, color: Colors.white, size: 14),
                                  SizedBox(width: 6),
                                  Text('Join Meeting', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                                ]),
                              ),
                            )
                          ],
                        ] else ...[
                          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                            const Icon(LucideIcons.checkCircle, color: Color(0xFF22C55E), size: 18),
                            const SizedBox(width: 10),
                            Text('Status: ${_existingAppStatus ?? 'Applied'}', style: const TextStyle(color: Color(0xFF22C55E), fontWeight: FontWeight.bold, fontSize: 15)),
                          ])
                        ]
                      ]),
                    )
                  : GestureDetector(
                      onTap: _applying ? null : _apply,
                      child: Container(
                        height: 54,
                        decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(0, 6))]),
                        child: Center(
                          child: _applying
                              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                              : Row(mainAxisSize: MainAxisSize.min, children: [
                                  Icon(aiEnabled ? LucideIcons.bot : LucideIcons.send, color: Colors.white, size: 18),
                                  const SizedBox(width: 10),
                                  Text(
                                    (_alreadyApplied && _existingAppStatus == 'ai_screening')
                                      ? 'Resume/Retry AI Interview'
                                      : (aiEnabled ? 'Apply & Take AI Interview' : 'Apply Now'), 
                                    style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)
                                  ),
                                ]),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metaChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withValues(alpha: 0.1))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: Colors.white38),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12)),
      ]),
    );
  }

  Widget _sectionHeader(String text) {
    return Text(text, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold));
  }
}
