import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:hustlr/core/theme/app_colors.dart';
import 'package:hustlr/core/widgets/gradient_card.dart';

class RoadmapDashboardPage extends StatelessWidget {
  const RoadmapDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(title: const Text('My Roadmap')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          GradientCard(
            gradient: AppColors.tealGradient,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Flutter Dev Roadmap', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              const Text('Goal: Senior Developer at a startup', style: TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 16),
              Row(children: [
                _pill('Week 8 of 24'),
                const SizedBox(width: 8),
                _pill('33% Done'),
              ]),
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: 0.33,
                backgroundColor: Colors.white24,
                valueColor: const AlwaysStoppedAnimation(Colors.white),
                borderRadius: BorderRadius.circular(4),
                minHeight: 7,
              ),
            ]),
          ),
          const SizedBox(height: 28),
          Text('Milestones', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          _milestone(context, 'Dart Foundations', true, isDark),
          _connector(true),
          _milestone(context, 'Flutter Widgets & Layouts', true, isDark),
          _connector(true),
          _milestone(context, 'State Management (Riverpod)', false, isDark, isCurrent: true),
          _connector(false),
          _milestone(context, 'Firebase & Backend', false, isDark),
          _connector(false),
          _milestone(context, 'Advanced UI & Animations', false, isDark),
          _connector(false),
          _milestone(context, 'Deploy & Publish', false, isDark),
        ]),
      ),
    );
  }

  Widget _pill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(20)),
      child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }

  Widget _milestone(BuildContext context, String title, bool done, bool isDark, {bool isCurrent = false}) {
    return Row(children: [
      Column(children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            color: done ? AppColors.success : isCurrent ? AppColors.primary : (isDark ? AppColors.surfaceDark2 : Colors.grey.shade200),
            shape: BoxShape.circle,
            border: isCurrent ? Border.all(color: AppColors.primary, width: 2) : null,
          ),
          child: Icon(
            done ? LucideIcons.check : isCurrent ? LucideIcons.clock : LucideIcons.circle,
            color: done || isCurrent ? Colors.white : AppColors.textSecondaryLight,
            size: 16,
          ),
        ),
      ]),
      const SizedBox(width: 14),
      Expanded(
        child: Container(
          padding: const EdgeInsets.all(14),
          margin: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: isCurrent ? AppColors.primary.withValues(alpha: 0.08) : isDark ? AppColors.surfaceDark : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isCurrent ? AppColors.primary.withValues(alpha: 0.3) : isDark ? Colors.white10 : Colors.black12),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(title, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: done ? AppColors.textSecondaryLight : null)),
            if (done) const Icon(LucideIcons.checkCircle2, color: AppColors.success, size: 16),
            if (isCurrent) const Text('In Progress', style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.bold)),
          ]),
        ),
      ),
    ]);
  }

  Widget _connector(bool done) {
    return Padding(
      padding: const EdgeInsets.only(left: 15),
      child: Container(
        width: 2, height: 20,
        color: done ? AppColors.success : AppColors.textSecondaryLight.withValues(alpha: 0.3),
      ),
    );
  }
}
