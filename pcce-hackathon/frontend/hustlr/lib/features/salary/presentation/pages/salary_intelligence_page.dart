import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:hustlr/core/theme/app_colors.dart';
import 'package:hustlr/core/widgets/glass_card.dart';

class SalaryIntelligencePage extends StatelessWidget {
  const SalaryIntelligencePage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(title: const Text('Salary Intelligence')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Market Value Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(gradient: AppColors.tealGradient, borderRadius: BorderRadius.circular(16)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Your Est. Market Value', style: TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 8),
              const Text('₹18.5L - ₹24.0L', style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('Based on your 92/100 ATS score and 2 YOE in Flutter.', style: TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(12)),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(LucideIcons.trendingUp, color: Colors.white, size: 16),
                  SizedBox(width: 8),
                  Text('+15% above average', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 24),
          Text('Market Average (Bangalore)', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          _percentileBar(isDark, '25th Percentile', '₹12.0L', 0.25, AppColors.textSecondaryLight),
          const SizedBox(height: 12),
          _percentileBar(isDark, 'Median (50th)', '₹16.0L', 0.50, AppColors.warning),
          const SizedBox(height: 12),
          _percentileBar(isDark, '75th Percentile', '₹22.0L', 0.75, AppColors.success),
          const SizedBox(height: 12),
          _percentileBar(isDark, '90th Percentile', '₹30.0L', 0.90, AppColors.primary),
          const SizedBox(height: 28),
          Text('AI Negotiation Tips', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 14),
          GlassCard(
            padding: const EdgeInsets.all(16),
            borderRadius: 14,
            child: Column(children: [
              _tipRow(LucideIcons.messageSquare, 'Highlight your open-source contributions. Companies value visible code.'),
              const Divider(height: 24),
              _tipRow(LucideIcons.shield, 'Don\'t disclose current CTC immediately. Ask for the budget first.'),
              const Divider(height: 24),
              _tipRow(LucideIcons.zap, 'You have high mock interview scores. Use that confidence to anchor high.'),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _percentileBar(bool isDark, String label, String value, double percent, Color color) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
        Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
      ]),
      const SizedBox(height: 6),
      Stack(children: [
        Container(height: 8, width: double.infinity, decoration: BoxDecoration(color: isDark ? Colors.white10 : Colors.black12, borderRadius: BorderRadius.circular(4))),
        FractionallySizedBox(
          widthFactor: percent,
          child: Container(height: 8, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4))),
        ),
      ]),
    ]);
  }

  Widget _tipRow(IconData icon, String text) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, color: AppColors.primary, size: 20),
      const SizedBox(width: 12),
      Expanded(child: Text(text, style: const TextStyle(fontSize: 13, height: 1.4))),
    ]);
  }
}
