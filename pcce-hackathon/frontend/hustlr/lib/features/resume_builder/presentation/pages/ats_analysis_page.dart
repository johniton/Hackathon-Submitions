import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:hustlr/core/theme/app_colors.dart';

class AtsAnalysisPage extends StatelessWidget {
  const AtsAnalysisPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(title: const Text('ATS Analysis')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Paste JD area
          Text('Paste Job Description', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Container(
            height: 130,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDark : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
            ),
            child: TextField(
              maxLines: null,
              expands: true,
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: 'Paste the job description here to match against your resume...',
                hintStyle: TextStyle(color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight, fontSize: 13),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(12)),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(LucideIcons.sparkles, color: Colors.white, size: 16),
                SizedBox(width: 8),
                Text('Analyze Match', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ]),
            ),
          ),
          const SizedBox(height: 28),
          // Results
          Text('Match Results', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 14),
          Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            _scoreDial(context, 'Overall', 0.87, AppColors.primary),
            _scoreDial(context, 'Keywords', 0.92, AppColors.success),
            _scoreDial(context, 'Format', 0.78, AppColors.accent),
          ]),
          const SizedBox(height: 24),
          Text('Matched Keywords', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: ['Flutter', 'Dart', 'Firebase', 'REST API', 'Git', 'Agile'].map((k) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.success.withValues(alpha: 0.3))),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(LucideIcons.check, size: 12, color: AppColors.success),
              const SizedBox(width: 4),
              Text(k, style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.w600, fontSize: 12)),
            ]),
          )).toList()),
          const SizedBox(height: 16),
          Text('Missing Keywords', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: ['CI/CD', 'Kubernetes', 'GraphQL'].map((k) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.error.withValues(alpha: 0.3))),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(LucideIcons.x, size: 12, color: AppColors.error),
              const SizedBox(width: 4),
              Text(k, style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.w600, fontSize: 12)),
            ]),
          )).toList()),
        ]),
      ),
    );
  }

  Widget _scoreDial(BuildContext context, String label, double value, Color color) {
    return Column(children: [
      SizedBox(width: 80, height: 80, child: Stack(alignment: Alignment.center, children: [
        CircularProgressIndicator(value: value, strokeWidth: 8, backgroundColor: color.withValues(alpha: 0.1), valueColor: AlwaysStoppedAnimation(color)),
        Text('${(value * 100).toInt()}%', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 15)),
      ])),
      const SizedBox(height: 6),
      Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
    ]);
  }
}
