import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:hustlr/core/theme/app_colors.dart';
import 'package:hustlr/core/widgets/glass_card.dart';

class CompanyJobsPage extends StatelessWidget {
  const CompanyJobsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(title: const Text('Applicants')),
      body: DefaultTabController(
        length: 3,
        child: Column(children: [
          const TabBar(
            labelColor: AppColors.primary,
            indicatorColor: AppColors.primary,
            tabs: [Tab(text: 'All (23)'), Tab(text: 'AI Screened (5)'), Tab(text: 'Shortlisted (3)')],
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: 4,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) {
                final names = ['Arjun Mehta', 'Priya Sharma', 'Ravi Kumar', 'Nisha Patel'];
                final scores = [88, 76, 91, 65];
                return GlassCard(
                  padding: const EdgeInsets.all(16),
                  borderRadius: 14,
                  child: Row(children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                      child: Text(names[i][0], style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(names[i], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      Text('AI Score: ${scores[i]}/100', style: TextStyle(
                        color: scores[i] >= 85 ? AppColors.success : AppColors.warning,
                        fontSize: 12, fontWeight: FontWeight.w600,
                      )),
                    ])),
                    Row(children: [
                      _actionBtn2(LucideIcons.eye, AppColors.primary, isDark),
                      const SizedBox(width: 8),
                      _actionBtn2(LucideIcons.check, AppColors.success, isDark),
                      const SizedBox(width: 8),
                      _actionBtn2(LucideIcons.x, AppColors.error, isDark),
                    ]),
                  ]),
                );
              },
            ),
          ),
        ]),
      ),
    );
  }

  Widget _actionBtn2(IconData icon, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
      child: Icon(icon, color: color, size: 16),
    );
  }
}
