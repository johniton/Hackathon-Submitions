import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:hustlr/core/theme/app_colors.dart';
import 'package:hustlr/core/widgets/glass_card.dart';

class PeerBenchmarkingPage extends StatelessWidget {
  const PeerBenchmarkingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(title: const Text('Peer Benchmarking')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(20)),
            child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
                Text('Your Percentile', style: TextStyle(color: Colors.white70, fontSize: 13)),
                SizedBox(height: 4),
                Text('Top 18%', style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.bold)),
                SizedBox(height: 4),
                Text('Among Flutter Devs in India', style: TextStyle(color: Colors.white70, fontSize: 12)),
              ])),
              const Icon(LucideIcons.trendingUp, color: Colors.white70, size: 40),
            ]),
          ),
          const SizedBox(height: 24),
          Text('Skills vs. Peers', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 14),
          _skillBar(context, 'Flutter / Dart', 0.87, 0.72, isDark),
          const SizedBox(height: 12),
          _skillBar(context, 'State Management', 0.74, 0.65, isDark),
          const SizedBox(height: 12),
          _skillBar(context, 'System Design', 0.45, 0.68, isDark),
          const SizedBox(height: 12),
          _skillBar(context, 'DSA', 0.55, 0.70, isDark),
          const SizedBox(height: 24),
          Text('Market Comparison', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 14),
          _compareRow('Resume ATS Score', '92', '74 avg', AppColors.success, isDark),
          const SizedBox(height: 10),
          _compareRow('Mock Interview Score', '78', '69 avg', AppColors.primary, isDark),
          const SizedBox(height: 10),
          _compareRow('Skill Match (Jobs)', '88%', '61% avg', AppColors.accent, isDark),
        ]),
      ),
    );
  }

  Widget _skillBar(BuildContext context, String label, double yours, double peers, bool isDark) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        Row(children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 4),
          const Text('You', style: TextStyle(fontSize: 11, color: AppColors.textSecondaryLight)),
          const SizedBox(width: 8),
          Container(width: 10, height: 10, decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 4),
          const Text('Peers', style: TextStyle(fontSize: 11, color: AppColors.textSecondaryLight)),
        ]),
      ]),
      const SizedBox(height: 6),
      Stack(children: [
        LinearProgressIndicator(value: peers, backgroundColor: AppColors.accent.withValues(alpha: 0.1), valueColor: AlwaysStoppedAnimation(AppColors.accent.withValues(alpha: 0.4)), borderRadius: BorderRadius.circular(4), minHeight: 10),
        LinearProgressIndicator(value: yours, backgroundColor: Colors.transparent, valueColor: const AlwaysStoppedAnimation(AppColors.primary), borderRadius: BorderRadius.circular(4), minHeight: 10),
      ]),
    ]);
  }

  Widget _compareRow(String label, String yours, String avg, Color color, bool isDark) {
    return GlassCard(
      padding: const EdgeInsets.all(14),
      borderRadius: 12,
      child: Row(children: [
        Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
        Text(yours, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(width: 8),
        Text(avg, style: const TextStyle(color: AppColors.textSecondaryLight, fontSize: 12)),
      ]),
    );
  }
}
