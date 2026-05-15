import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:hustlr/core/theme/app_colors.dart';
import 'package:hustlr/core/widgets/glass_card.dart';
import 'package:hustlr/core/widgets/gradient_card.dart';
import 'package:hustlr/core/widgets/section_header.dart';
import 'package:hustlr/features/ai_interview/presentation/pages/interview_setup_page.dart';

class InterviewDashboardPage extends StatelessWidget {
  const InterviewDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('AI Interview', style: Theme.of(context).textTheme.headlineLarge),
              const SizedBox(height: 4),
              Text('Practice & get hired faster', style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 24),

              // Mode selector — all go to InterviewSetupPage
              Row(
                children: [
                  Expanded(child: _modeCard(context, 'Mock\nInterview', LucideIcons.graduationCap, AppColors.primaryGradient, 'Practice freely')),
                  const SizedBox(width: 14),
                  Expanded(child: _modeCard(context, 'Technical\nRound', LucideIcons.code2, AppColors.purpleGradient, 'DSA & System design')),
                  const SizedBox(width: 14),
                  Expanded(child: _modeCard(context, 'HR\nRound', LucideIcons.users, AppColors.tealGradient, 'Behavioral questions')),
                ],
              ),
              const SizedBox(height: 32),

              GradientCard(
                gradient: AppColors.primaryGradient,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(LucideIcons.sparkles, color: Colors.white70, size: 16),
                        const SizedBox(width: 6),
                        const Text('AI-Powered Interview', style: TextStyle(color: Colors.white70, fontSize: 13)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Get company-specific mock interviews powered by AI. Research your target company, practice with adaptive questions, and get detailed performance scoring.',
                      style: TextStyle(color: Colors.white, fontSize: 13, height: 1.5),
                    ),
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InterviewSetupPage())),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(LucideIcons.play, color: AppColors.primary, size: 16),
                            SizedBox(width: 8),
                            Text('Start Now', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 13)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              const SectionHeader(title: 'Recent Sessions', actionLabel: 'View All'),
              const SizedBox(height: 16),
              _sessionCard(context, 'Flutter Engineer @ Google', 'Mock Interview', '12 May 2026', '78/100', isDark),
              const SizedBox(height: 12),
              _sessionCard(context, 'Backend Developer @ Swiggy', 'Technical Round', '10 May 2026', '65/100', isDark),
              const SizedBox(height: 12),
              _sessionCard(context, 'SDE-1 @ Zepto', 'HR Round', '8 May 2026', '91/100', isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _modeCard(BuildContext context, String title, IconData icon, LinearGradient gradient, String sub) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InterviewSetupPage())),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: gradient.colors.first.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 6))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Colors.white, size: 24),
            const SizedBox(height: 10),
            Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13, height: 1.3)),
            const SizedBox(height: 4),
            Text(sub, style: const TextStyle(color: Colors.white70, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _sessionCard(BuildContext context, String role, String type, String date, String score, bool isDark) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      borderRadius: 14,
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
            child: const Icon(LucideIcons.bot, color: AppColors.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(role, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 3),
                Text('$type  ·  $date', style: TextStyle(fontSize: 12, color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(score, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 4),
              const Text('View →', style: TextStyle(color: AppColors.accent, fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }
}
