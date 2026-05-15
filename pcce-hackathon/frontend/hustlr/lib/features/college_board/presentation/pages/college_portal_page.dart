import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:hustlr/core/theme/app_colors.dart';
import 'package:hustlr/core/widgets/glass_card.dart';

class CollegePortalPage extends StatelessWidget {
  const CollegePortalPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(title: const Text('Institution Portal')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(gradient: AppColors.purpleGradient, borderRadius: BorderRadius.circular(16)),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle),
                child: const Icon(LucideIcons.graduationCap, color: Colors.white, size: 32),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('IIT Bombay', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  Text('Placement Dashboard 2026', style: TextStyle(color: Colors.white70, fontSize: 13)),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 24),
          Row(children: [
            Expanded(child: _statCard(isDark, 'Placed', '82%', AppColors.success, LucideIcons.trendingUp)),
            const SizedBox(width: 12),
            Expanded(child: _statCard(isDark, 'Avg LPA', '₹18.5', AppColors.primary, LucideIcons.indianRupee)),
            const SizedBox(width: 12),
            Expanded(child: _statCard(isDark, 'Companies', '45', AppColors.accent, LucideIcons.building2)),
          ]),
          const SizedBox(height: 24),
          Text('Top Recruiting Companies', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          GlassCard(
            padding: const EdgeInsets.all(16),
            borderRadius: 14,
            child: Column(children: [
              _companyRow('Google', '12 offers', AppColors.primary),
              const Divider(height: 24),
              _companyRow('Razorpay', '8 offers', AppColors.accent),
              const Divider(height: 24),
              _companyRow('Meesho', '5 offers', AppColors.accentOrange),
            ]),
          ),
          const SizedBox(height: 24),
          Text('Student Readiness (AI)', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDark : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
            ),
            child: Column(children: [
              _progressRow('Resume Scores > 80', 0.65, AppColors.success),
              const SizedBox(height: 12),
              _progressRow('Mock Interview > 70', 0.45, AppColors.warning),
              const SizedBox(height: 12),
              _progressRow('Skill Matches', 0.80, AppColors.primary),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _statCard(bool isDark, String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
      ),
      child: Column(children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 8),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        Text(label, style: const TextStyle(color: AppColors.textSecondaryLight, fontSize: 11)),
      ]),
    );
  }

  Widget _companyRow(String name, String offers, Color color) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
        child: Text(offers, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
      ),
    ]);
  }

  Widget _progressRow(String label, double value, Color color) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
        Text('${(value * 100).toInt()}%', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
      ]),
      const SizedBox(height: 6),
      LinearProgressIndicator(
        value: value,
        backgroundColor: color.withValues(alpha: 0.1),
        valueColor: AlwaysStoppedAnimation(color),
        borderRadius: BorderRadius.circular(4),
        minHeight: 6,
      ),
    ]);
  }
}
