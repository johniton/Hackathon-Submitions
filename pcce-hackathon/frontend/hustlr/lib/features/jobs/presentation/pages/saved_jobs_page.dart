import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:hustlr/core/theme/app_colors.dart';
import 'package:hustlr/core/widgets/glass_card.dart';

class SavedJobsPage extends StatelessWidget {
  const SavedJobsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(title: const Text('Saved Jobs')),
      body: ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: 3,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, i) {
          final jobs = [
            {'role': 'Flutter Developer', 'company': 'Razorpay', 'salary': '₹18–24 LPA', 'status': 'Applied', 'statusColor': AppColors.success},
            {'role': 'React Native Dev', 'company': 'CRED', 'salary': '₹20–28 LPA', 'status': 'Viewed', 'statusColor': AppColors.warning},
            {'role': 'SDE-1 Android', 'company': 'Meesho', 'salary': '₹12–18 LPA', 'status': 'Saved', 'statusColor': AppColors.primary},
          ];
          final j = jobs[i];
          return GlassCard(
            padding: const EdgeInsets.all(16),
            borderRadius: 14,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(width: 40, height: 40, decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)), child: const Icon(LucideIcons.building2, color: AppColors.primary, size: 18)),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(j['role'] as String, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  Text(j['company'] as String, style: const TextStyle(color: AppColors.textSecondaryLight, fontSize: 12)),
                ])),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: (j['statusColor'] as Color).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                  child: Text(j['status'] as String, style: TextStyle(color: j['statusColor'] as Color, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                const Icon(LucideIcons.indianRupee, size: 12, color: AppColors.textSecondaryLight),
                const SizedBox(width: 4),
                Text(j['salary'] as String, style: const TextStyle(color: AppColors.textSecondaryLight, fontSize: 12)),
                const Spacer(),
                const Icon(LucideIcons.bookmark, color: AppColors.primary, size: 16),
              ]),
            ]),
          );
        },
      ),
    );
  }
}
