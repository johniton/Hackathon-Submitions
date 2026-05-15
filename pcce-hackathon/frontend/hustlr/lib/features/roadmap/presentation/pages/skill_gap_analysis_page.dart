import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:hustlr/core/theme/app_colors.dart';
import 'package:hustlr/core/widgets/glass_card.dart';

class SkillGapAnalysisPage extends StatelessWidget {
  const SkillGapAnalysisPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(title: const Text('Skill Gap Analysis')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDark : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Target Role', style: TextStyle(color: AppColors.textSecondaryLight, fontSize: 13)),
              const SizedBox(height: 4),
              const Text('Senior Flutter Developer', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 2),
              const Text('@ Startup · ₹20–30 LPA', style: TextStyle(color: AppColors.accent, fontSize: 13)),
            ]),
          ),
          const SizedBox(height: 24),
          Text('Skill Coverage', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 14),
          _gapRow('Flutter', 0.90, true, isDark),
          const SizedBox(height: 10),
          _gapRow('Dart / OOP', 0.85, true, isDark),
          const SizedBox(height: 10),
          _gapRow('State Management', 0.70, true, isDark),
          const SizedBox(height: 10),
          _gapRow('CI/CD & DevOps', 0.35, false, isDark),
          const SizedBox(height: 10),
          _gapRow('System Design', 0.45, false, isDark),
          const SizedBox(height: 10),
          _gapRow('Testing (TDD)', 0.30, false, isDark),
          const SizedBox(height: 24),
          Text('Priority Learning', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 14),
          _resourceCard('GitHub Actions Crash Course', 'CI/CD', LucideIcons.video, AppColors.primary, isDark),
          const SizedBox(height: 10),
          _resourceCard('System Design for Mobile', 'Architecture', LucideIcons.bookOpen, AppColors.accentPurple, isDark),
          const SizedBox(height: 10),
          _resourceCard('Flutter Testing Guide', 'Testing', LucideIcons.checkSquare, AppColors.success, isDark),
        ]),
      ),
    );
  }

  Widget _gapRow(String skill, double level, bool strong, bool isDark) {
    final color = strong ? AppColors.success : AppColors.warning;
    return Row(children: [
      Expanded(
        flex: 3,
        child: Text(skill, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
      ),
      Expanded(
        flex: 5,
        child: LinearProgressIndicator(value: level, backgroundColor: color.withValues(alpha: 0.1), valueColor: AlwaysStoppedAnimation(color), borderRadius: BorderRadius.circular(4), minHeight: 8),
      ),
      const SizedBox(width: 10),
      Text('${(level * 100).toInt()}%', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
    ]);
  }

  Widget _resourceCard(String title, String category, IconData icon, Color color, bool isDark) {
    return GlassCard(
      padding: const EdgeInsets.all(14),
      borderRadius: 12,
      child: Row(children: [
        Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)), child: Icon(icon, color: color, size: 18)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          Text(category, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
        ])),
        const Icon(LucideIcons.externalLink, size: 16, color: AppColors.textSecondaryLight),
      ]),
    );
  }
}
