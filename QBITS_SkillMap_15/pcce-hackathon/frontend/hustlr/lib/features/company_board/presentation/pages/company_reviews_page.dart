import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:hustlr/core/theme/app_colors.dart';
import 'package:hustlr/core/widgets/glass_card.dart';

class CompanyReviewsPage extends StatelessWidget {
  const CompanyReviewsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(title: const Text('Company Reviews')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Header Stats
          GlassCard(
            padding: const EdgeInsets.all(20),
            borderRadius: 16,
            child: Row(children: [
              Column(children: [
                const Text('4.2', style: TextStyle(fontSize: 42, fontWeight: FontWeight.bold, color: AppColors.primary)),
                Row(children: List.generate(5, (index) => Icon(LucideIcons.star, size: 14, color: index < 4 ? AppColors.warning : AppColors.textSecondaryLight))),
                const SizedBox(height: 4),
                const Text('Based on 128 reviews', style: TextStyle(fontSize: 10, color: AppColors.textSecondaryLight)),
              ]),
              const SizedBox(width: 20),
              Expanded(
                child: Column(children: [
                  _ratingBar('Work/Life', 0.8),
                  const SizedBox(height: 6),
                  _ratingBar('Salary', 0.9),
                  const SizedBox(height: 6),
                  _ratingBar('Growth', 0.7),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 24),
          const Text('Top Reviews', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          // Review Items
          _reviewCard(
            isDark: isDark,
            role: 'Software Engineer',
            status: 'Current Employee',
            rating: 4,
            pros: 'Great engineering culture, modern tech stack, flexible hours.',
            cons: 'Can be high pressure during release weeks.',
            verified: true,
          ),
          const SizedBox(height: 12),
          _reviewCard(
            isDark: isDark,
            role: 'Product Manager',
            status: 'Former Employee',
            rating: 3,
            pros: 'Good perks and benefits. Learned a lot.',
            cons: 'Management structure changes frequently.',
            verified: false,
          ),
        ]),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {},
        backgroundColor: AppColors.primary,
        icon: const Icon(LucideIcons.penTool, color: Colors.white),
        label: const Text('Write Review', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _ratingBar(String label, double value) {
    return Row(children: [
      SizedBox(width: 60, child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500))),
      const SizedBox(width: 8),
      Expanded(
        child: LinearProgressIndicator(
          value: value,
          backgroundColor: AppColors.primary.withValues(alpha: 0.1),
          valueColor: const AlwaysStoppedAnimation(AppColors.primary),
          borderRadius: BorderRadius.circular(4),
          minHeight: 6,
        ),
      ),
    ]);
  }

  Widget _reviewCard({
    required bool isDark,
    required String role,
    required String status,
    required int rating,
    required String pros,
    required String cons,
    required bool verified,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(role, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          Row(children: List.generate(5, (index) => Icon(LucideIcons.star, size: 14, color: index < rating ? AppColors.warning : AppColors.textSecondaryLight))),
        ]),
        const SizedBox(height: 4),
        Row(children: [
          Text(status, style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight)),
          if (verified) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
              child: const Row(children: [
                Icon(LucideIcons.checkCircle2, size: 10, color: AppColors.success),
                SizedBox(width: 4),
                Text('Verified', style: TextStyle(fontSize: 10, color: AppColors.success, fontWeight: FontWeight.bold)),
              ]),
            ),
          ],
        ]),
        const Divider(height: 24),
        const Text('Pros', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.success)),
        const SizedBox(height: 4),
        Text(pros, style: const TextStyle(fontSize: 13, height: 1.4)),
        const SizedBox(height: 12),
        const Text('Cons', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.error)),
        const SizedBox(height: 4),
        Text(cons, style: const TextStyle(fontSize: 13, height: 1.4)),
      ]),
    );
  }
}
