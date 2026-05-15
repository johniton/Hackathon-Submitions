import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hustlr/core/theme/app_colors.dart';
import 'package:hustlr/features/skill_swap/data/google_calendar_service.dart';

class CompanyApplicantsPage extends StatefulWidget {
  final Map<String, dynamic> job;
  const CompanyApplicantsPage({super.key, required this.job});

  @override
  State<CompanyApplicantsPage> createState() => _CompanyApplicantsPageState();
}

class _CompanyApplicantsPageState extends State<CompanyApplicantsPage> {
  final _db = Supabase.instance.client;
  List<Map<String, dynamic>> _applicants = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final res = await _db
        .from('job_applications')
        .select('*, users(id, name, email, phone)')
        .eq('job_id', widget.job['id'])
        .order('applied_at', ascending: false);
    if (mounted) {
      setState(() {
        _applicants = List<Map<String, dynamic>>.from(res ?? []);
        _loading = false;
      });
    }
  }

  Future<void> _scheduleInterview(Map<String, dynamic> app) async {
    final user = app['users'] as Map<String, dynamic>?;
    final userEmail = user?['email'] as String?;
    final userName = user?['name'] as String? ?? 'Candidate';

    DateTime? picked;
    await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 2)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 60)),
    ).then((date) async {
      if (date == null) return;
      final time = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 10, minute: 0));
      if (time == null) return;
      picked = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });

    if (picked == null) return;

    final meetLink = GoogleCalendarService.instance.generateVideoCallLink();

    await GoogleCalendarService.instance.createEvent(
      title: 'Interview: ${userName} for ${widget.job['title']}',
      startTime: picked!,
      durationMinutes: 60,
      description: 'Technical interview for ${widget.job['title']} position.\nMeet Link: $meetLink',
      peerEmail: userEmail,
    );

    await _db.from('job_applications').update({
      'status': 'scheduled',
      'interview_scheduled_at': picked!.toIso8601String(),
      'interview_meet_link': meetLink,
    }).eq('id', app['id']);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Interview scheduled & calendar event created!')));
      _load();
    }
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'ai_passed': return const Color(0xFF22C55E);
      case 'ai_failed': return const Color(0xFFEF4444);
      case 'scheduled': return const Color(0xFF3B82F6);
      case 'hired': return AppColors.primary;
      case 'rejected': return Colors.white38;
      default: return const Color(0xFFF59E0B);
    }
  }

  String _statusLabel(String? status) {
    switch (status) {
      case 'applied': return 'Applied';
      case 'ai_screening': return 'Screening';
      case 'ai_passed': return 'AI Passed';
      case 'ai_failed': return 'AI Failed';
      case 'scheduled': return 'Scheduled';
      case 'hired': return 'Hired';
      case 'rejected': return 'Rejected';
      default: return status ?? 'Unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
    final aiEnabled = widget.job['ai_screening_enabled'] == true;
    final threshold = widget.job['ai_score_threshold'] ?? 60;

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
                    child: Container(
                      width: 38, height: 38,
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(10)),
                      child: const Icon(LucideIcons.arrowLeft, color: Colors.white70, size: 18),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.job['title'] ?? 'Job', style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                        Row(children: [
                          Text('${_applicants.length} applicants', style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12)),
                          if (aiEnabled) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
                              child: Text('AI Screen ≥ $threshold', style: const TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.w700)),
                            ),
                          ],
                        ]),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: Colors.white))
                  : _applicants.isEmpty
                      ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(LucideIcons.users, color: Colors.white.withValues(alpha: 0.2), size: 60),
                          const SizedBox(height: 16),
                          Text('No applicants yet', style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 16)),
                        ]))
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _applicants.length,
                            itemBuilder: (_, i) => _buildCard(_applicants[i], threshold),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(Map<String, dynamic> app, int threshold) {
    final user = app['users'] as Map<String, dynamic>?;
    final name = user?['name'] as String? ?? 'Unknown';
    final email = user?['email'] as String? ?? '';
    final status = app['status'] as String?;
    final score = app['ai_composite_score'];
    final tier = app['ai_performance_tier'] as String?;
    final passed = app['ai_screening_passed'] == true;
    final scheduled = status == 'scheduled';
    final meetLink = app['interview_meet_link'] as String?;
    final cheatCount = (app['cheat_count'] as int?) ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42, height: 42,
                  decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(12)),
                  child: Center(child: Text(name.substring(0, 1).toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18))),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
                    Text(email, style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12)),
                    if (cheatCount > 0) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(LucideIcons.shieldAlert, color: Color(0xFFEF4444), size: 10),
                            const SizedBox(width: 4),
                            Text(
                              '🚩 Cheating Detected: $cheatCount ${cheatCount == 1 ? 'time' : 'times'}',
                              style: const TextStyle(color: Color(0xFFEF4444), fontSize: 10, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ]),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statusColor(status).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(_statusLabel(status), style: TextStyle(color: _statusColor(status), fontSize: 11, fontWeight: FontWeight.w700)),
                ),
              ],
            ),

            // AI Score display
            if (score != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: passed ? const Color(0xFF22C55E).withValues(alpha: 0.08) : const Color(0xFFEF4444).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: passed ? const Color(0xFF22C55E).withValues(alpha: 0.2) : const Color(0xFFEF4444).withValues(alpha: 0.2)),
                ),
                child: Row(children: [
                  Icon(passed ? LucideIcons.checkCircle : LucideIcons.xCircle, color: passed ? const Color(0xFF22C55E) : const Color(0xFFEF4444), size: 18),
                  const SizedBox(width: 10),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('AI Score: ${score.toStringAsFixed(1)}/100  •  ${tier ?? 'N/A'}',
                      style: TextStyle(color: passed ? const Color(0xFF22C55E) : const Color(0xFFEF4444), fontWeight: FontWeight.w700, fontSize: 13)),
                    Text(passed ? 'Passed screening threshold ($threshold)' : 'Below threshold ($threshold)',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 11)),
                  ]),
                ]),
              ),
            ],

            if (scheduled && meetLink != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: const Color(0xFF3B82F6).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                child: Row(children: [
                  const Icon(LucideIcons.video, color: Color(0xFF3B82F6), size: 14),
                  const SizedBox(width: 8),
                  Expanded(child: Text('Interview Scheduled: $meetLink', style: const TextStyle(color: Color(0xFF3B82F6), fontSize: 11), overflow: TextOverflow.ellipsis)),
                ]),
              ),
            ],

            // Action: Schedule button (only if passed and not yet scheduled)
            if (passed && !scheduled) ...[
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () => _scheduleInterview(app),
                child: Container(
                  height: 42,
                  decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(10)),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(LucideIcons.calendarPlus, color: Colors.white, size: 16),
                      SizedBox(width: 8),
                      Text('Schedule Interview', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
