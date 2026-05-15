import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:hustlr/core/theme/app_colors.dart';
import 'package:hustlr/core/widgets/glass_card.dart';

class AlumniNetworkPage extends StatelessWidget {
  const AlumniNetworkPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(title: const Text('Alumni & Referrals')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDark : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
            ),
            child: Row(children: [
              const Icon(LucideIcons.search, color: AppColors.textSecondaryLight, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Search alumni by company...',
                    hintStyle: TextStyle(color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight, fontSize: 14),
                  ),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 24),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Warm Connections', style: Theme.of(context).textTheme.titleLarge),
            const Text('IIT Bombay', style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 16),
          _alumniCard(
            isDark: isDark,
            name: 'Karan Mehta',
            gradYear: '2022',
            company: 'Google',
            role: 'Software Engineer II',
            match: '92%',
          ),
          const SizedBox(height: 12),
          _alumniCard(
            isDark: isDark,
            name: 'Sneha Joshi',
            gradYear: '2023',
            company: 'Razorpay',
            role: 'Frontend Developer',
            match: '85%',
          ),
          const SizedBox(height: 12),
          _alumniCard(
            isDark: isDark,
            name: 'Pranav Nair',
            gradYear: '2021',
            company: 'CRED',
            role: 'Product Manager',
            match: '70%',
          ),
        ]),
      ),
    );
  }

  Widget _alumniCard({
    required bool isDark,
    required String name,
    required String gradYear,
    required String company,
    required String role,
    required String match,
  }) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      borderRadius: 14,
      child: Row(children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: AppColors.primary.withValues(alpha: 0.1),
          child: Text(name[0], style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 18)),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: AppColors.textSecondaryLight.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                child: Text('Class of $gradYear', style: const TextStyle(fontSize: 9, color: AppColors.textSecondaryLight, fontWeight: FontWeight.bold)),
              ),
            ]),
            const SizedBox(height: 2),
            Text('$role @ $company', style: const TextStyle(color: AppColors.textSecondaryLight, fontSize: 12)),
          ]),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('$match Match', style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.bold, fontSize: 11)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
            child: const Row(children: [
              Icon(LucideIcons.messageCircle, size: 12, color: AppColors.primary),
              SizedBox(width: 4),
              Text('Ask Referral', style: TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.bold)),
            ]),
          ),
        ]),
      ]),
    );
  }
}
