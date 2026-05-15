import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:hustlr/core/theme/app_colors.dart';
import 'package:hustlr/core/widgets/glass_card.dart';

class CompanyPortalPage extends StatelessWidget {
  const CompanyPortalPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(title: const Text('Company Portal')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          GlassCard(
            padding: const EdgeInsets.all(18),
            borderRadius: 16,
            child: Row(children: [
              Container(width: 56, height: 56, decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14)), child: const Icon(LucideIcons.building2, color: AppColors.primary, size: 28)),
              const SizedBox(width: 14),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
                Text('Razorpay', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                Text('Fintech · Bangalore', style: TextStyle(color: AppColors.textSecondaryLight)),
                Row(children: [
                  Icon(LucideIcons.checkCircle2, size: 13, color: AppColors.success),
                  SizedBox(width: 4),
                  Text('Verified Company', style: TextStyle(color: AppColors.success, fontSize: 12, fontWeight: FontWeight.w600)),
                ]),
              ]),
            ]),
          ),
          const SizedBox(height: 24),
          Row(children: [
            Expanded(child: _statCard('Active JDs', '3', LucideIcons.briefcase, AppColors.primary, isDark)),
            const SizedBox(width: 12),
            Expanded(child: _statCard('Applicants', '127', LucideIcons.users, AppColors.accent, isDark)),
            const SizedBox(width: 12),
            Expanded(child: _statCard('Interviewed', '18', LucideIcons.bot, AppColors.accentOrange, isDark)),
          ]),
          const SizedBox(height: 24),
          Text('Active Job Posts', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 14),
          _jobPost('Flutter Developer', '23 applicants', '5 AI-screened', AppColors.primary, isDark),
          const SizedBox(height: 10),
          _jobPost('Backend Engineer', '68 applicants', '12 AI-screened', AppColors.accent, isDark),
          const SizedBox(height: 10),
          _jobPost('DevOps Engineer', '36 applicants', '8 AI-screened', AppColors.accentOrange, isDark),
        ]),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {},
        backgroundColor: AppColors.primary,
        label: const Text('Post New Job', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        icon: const Icon(LucideIcons.plus, color: Colors.white),
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(color: isDark ? AppColors.surfaceDark : Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: isDark ? Colors.white10 : Colors.black12)),
      child: Column(children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 6),
        Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 18)),
        Text(label, style: const TextStyle(color: AppColors.textSecondaryLight, fontSize: 11), textAlign: TextAlign.center),
      ]),
    );
  }

  Widget _jobPost(String title, String applicants, String screened, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: isDark ? AppColors.surfaceDark : Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: isDark ? Colors.white10 : Colors.black12)),
      child: Row(children: [
        Container(width: 4, height: 50, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4))),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 2),
          Text(applicants, style: const TextStyle(color: AppColors.textSecondaryLight, fontSize: 12)),
          Text(screened, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
        ])),
        const Icon(LucideIcons.chevronRight, color: AppColors.textSecondaryLight, size: 20),
      ]),
    );
  }
}
