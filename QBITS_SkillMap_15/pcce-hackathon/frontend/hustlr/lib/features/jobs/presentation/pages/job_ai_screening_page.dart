import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:hustlr/core/theme/app_colors.dart';
import 'package:hustlr/features/ai_interview/data/interview_models.dart';
import 'package:hustlr/features/ai_interview/presentation/pages/interview_live_page.dart';

class JobAiScreeningPage extends StatefulWidget {
  final Map<String, dynamic> job;
  final String applicationId;
  const JobAiScreeningPage({super.key, required this.job, required this.applicationId});

  @override
  State<JobAiScreeningPage> createState() => _JobAiScreeningPageState();
}

class _JobAiScreeningPageState extends State<JobAiScreeningPage> {
  bool _started = false;

  @override
  Widget build(BuildContext context) {
    final job = widget.job;
    final threshold = job['ai_score_threshold'] ?? 60;
    final topics = job['ai_interview_topics'] as String?;
    final customQs = (job['ai_custom_questions'] as List?)?.cast<String>();

    if (_started) {
      final setup = InterviewSetup(
        userId: null, // will be set by session
        jobRole: job['title'] ?? 'General',
        targetCompanies: [],
        interviewType: job['ai_interview_type'] ?? 'TECHNICAL',
        difficulty: job['ai_difficulty'] ?? 'MID',
        screeningContext: topics,
        customQuestions: customQs,
      );
      return InterviewLivePage(
        setup: setup,
        applicationId: widget.applicationId,
        jobScoreThreshold: threshold,
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(width: 38, height: 38, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(10)), child: const Icon(LucideIcons.arrowLeft, color: Colors.white70, size: 18)),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 20),
                    Container(
                      width: 80, height: 80,
                      decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(24)),
                      child: const Icon(LucideIcons.bot, color: Colors.white, size: 40),
                    ),
                    const SizedBox(height: 24),
                    Text('AI Screening Interview', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                    const SizedBox(height: 8),
                    Text('for ${job['title']}', style: TextStyle(color: AppColors.primary, fontSize: 15, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
                    const SizedBox(height: 24),

                    // Info Cards
                    _infoCard(LucideIcons.target, 'Minimum Pass Score', '$threshold / 100', AppColors.primary),
                    const SizedBox(height: 12),
                    _infoCard(LucideIcons.clock, 'Estimated Duration', '15-20 minutes', const Color(0xFFF59E0B)),
                    const SizedBox(height: 12),
                    _infoCard(LucideIcons.mic, 'Format', 'Video answers to AI questions', const Color(0xFF3B82F6)),
                    const SizedBox(height: 24),

                    if (topics != null) ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.04), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white.withValues(alpha: 0.08))),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            const Icon(LucideIcons.messageSquare, color: Colors.white38, size: 14),
                            const SizedBox(width: 8),
                            Text('INTERVIEW FOCUS', style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
                          ]),
                          const SizedBox(height: 8),
                          Text(topics, style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13, height: 1.5)),
                        ]),
                      ),
                      const SizedBox(height: 24),
                    ],

                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: const Color(0xFFF59E0B).withValues(alpha: 0.08), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.2))),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Row(children: [
                          Icon(LucideIcons.alertCircle, color: Color(0xFFF59E0B), size: 14),
                          SizedBox(width: 6),
                          Text('BEFORE YOU START', style: TextStyle(color: Color(0xFFF59E0B), fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1)),
                        ]),
                        const SizedBox(height: 10),
                        ...[
                          'Ensure you are in a quiet, well-lit room',
                          'Your camera and microphone must be working',
                          'You cannot pause or restart the interview',
                          'Speak clearly and concisely in your answers',
                        ].map((t) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('• ', style: TextStyle(color: const Color(0xFFF59E0B).withValues(alpha: 0.7))),
                            Expanded(child: Text(t, style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 12, height: 1.4))),
                          ]),
                        )),
                      ]),
                    ),
                    const SizedBox(height: 36),
                  ],
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
              child: GestureDetector(
                onTap: () => setState(() => _started = true),
                child: Container(
                  height: 56,
                  decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.4), blurRadius: 16, offset: const Offset(0, 6))]),
                  child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(LucideIcons.play, color: Colors.white, size: 20),
                    SizedBox(width: 10),
                    Text("I'm Ready — Start Interview", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  ]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoCard(IconData icon, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withValues(alpha: 0.2))),
      child: Row(children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 11)),
          Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
        ]),
      ]),
    );
  }
}
