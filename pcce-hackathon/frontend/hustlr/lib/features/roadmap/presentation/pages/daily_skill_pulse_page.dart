import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:hustlr/core/theme/app_colors.dart';
import 'package:hustlr/core/widgets/glass_card.dart';

class DailySkillPulsePage extends StatelessWidget {
  const DailySkillPulsePage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(title: const Text('Daily Skill Pulse')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(gradient: AppColors.orangeGradient, borderRadius: BorderRadius.circular(16)),
            child: Row(children: [
              const Icon(LucideIcons.flame, color: Colors.white, size: 36),
              const SizedBox(width: 16),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
                  Text('Trending Today', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  SizedBox(height: 4),
                  Text('AI curated tech news & market shifts tailored to your Flutter roadmap.', style: TextStyle(color: Colors.white70, fontSize: 13)),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 24),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Market Shifts', style: Theme.of(context).textTheme.titleLarge),
            const Icon(LucideIcons.sliders, color: AppColors.textSecondaryLight, size: 20),
          ]),
          const SizedBox(height: 16),
          _newsCard(
            isDark: isDark,
            category: 'Tech Trend',
            catColor: AppColors.primary,
            title: 'Flutter 3.20 Released with Impeller default on Android',
            time: '2 hours ago',
            reads: '4.2k reads',
          ),
          const SizedBox(height: 14),
          _newsCard(
            isDark: isDark,
            category: 'Hiring Shift',
            catColor: AppColors.warning,
            title: 'Fintech startups see 40% spike in hiring for Mobile Engineers.',
            time: '5 hours ago',
            reads: '1.8k reads',
          ),
          const SizedBox(height: 14),
          _newsCard(
            isDark: isDark,
            category: 'Skill Alert',
            catColor: AppColors.success,
            title: 'Riverpod 2.0 is now the standard for 80% of new Flutter roles.',
            time: 'Yesterday',
            reads: '5.1k reads',
          ),
        ]),
      ),
    );
  }

  Widget _newsCard({
    required bool isDark,
    required String category,
    required Color catColor,
    required String title,
    required String time,
    required String reads,
  }) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      borderRadius: 14,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: catColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
            child: Text(category, style: TextStyle(color: catColor, fontSize: 10, fontWeight: FontWeight.bold)),
          ),
          const Icon(LucideIcons.bookmark, size: 16, color: AppColors.textSecondaryLight),
        ]),
        const SizedBox(height: 12),
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, height: 1.4)),
        const SizedBox(height: 12),
        Row(children: [
          const Icon(LucideIcons.clock, size: 12, color: AppColors.textSecondaryLight),
          const SizedBox(width: 4),
          Text(time, style: const TextStyle(fontSize: 11, color: AppColors.textSecondaryLight)),
          const SizedBox(width: 12),
          const Icon(LucideIcons.eye, size: 12, color: AppColors.textSecondaryLight),
          const SizedBox(width: 4),
          Text(reads, style: const TextStyle(fontSize: 11, color: AppColors.textSecondaryLight)),
        ]),
      ]),
    );
  }
}
