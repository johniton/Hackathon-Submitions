import 'package:flutter/material.dart';
import 'package:hustlr/core/theme/app_colors.dart';

class BadgesPage extends StatelessWidget {
  const BadgesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(title: const Text('Badges & Achievements')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Stats row
          Row(children: [
            Expanded(child: _statCard('Earned', '8', AppColors.warning, isDark)),
            const SizedBox(width: 10),
            Expanded(child: _statCard('Locked', '12', AppColors.textSecondaryLight, isDark)),
            const SizedBox(width: 10),
            Expanded(child: _statCard('Total XP', '2.4k', AppColors.primary, isDark)),
          ]),
          const SizedBox(height: 24),

          _section(context, '🎤 Interview Badges'),
          const SizedBox(height: 12),
          _badgeRow([
            _Badge('First Interview', '🎤', 'Complete 1 mock interview', true, 1.0),
            _Badge('Interview Pro', '🎯', 'Score 90%+ in 5 interviews', true, 1.0),
            _Badge('Mock Master', '👑', 'Complete 25 mock interviews', false, 0.6),
          ], isDark),
          const SizedBox(height: 24),

          _section(context, '🔄 Skill Swap Badges'),
          const SizedBox(height: 12),
          _badgeRow([
            _Badge('First Swap', '🤝', 'Complete your first swap', true, 1.0),
            _Badge('5-Swap Legend', '🔄', 'Complete 5 skill swaps', true, 1.0),
            _Badge('Swap Master', '⚡', 'Complete 20 skill swaps', false, 0.35),
          ], isDark),
          const SizedBox(height: 24),

          _section(context, '🗺️ Learning Badges'),
          const SizedBox(height: 12),
          _badgeRow([
            _Badge('Roadmap Starter', '🚀', 'Start your first roadmap', true, 1.0),
            _Badge('Roadmap Finisher', '🗺️', 'Finish an entire roadmap', false, 0.72),
            _Badge('Flashcard Pro', '🧠', 'Master 100 flashcards', true, 1.0),
          ], isDark),
          const SizedBox(height: 24),

          _section(context, '💬 Community Badges'),
          const SizedBox(height: 12),
          _badgeRow([
            _Badge('Helpful Hero', '💬', 'Get 10 upvotes on answers', true, 1.0),
            _Badge('Top 10 Weekly', '🏆', 'Reach top 10 leaderboard', false, 0.0),
            _Badge('7-Day Streak', '🔥', 'Maintain 7-day streak', true, 1.0),
          ], isDark),
          const SizedBox(height: 24),

          _section(context, '✅ Mentor Badges'),
          const SizedBox(height: 12),
          _badgeRow([
            _Badge('Verified Mentor', '✅', 'Reach 500+ karma', false, 0.64),
            _Badge('Guru Status', '🧘', 'Reach 2000+ karma', false, 0.16),
            _Badge('Hall of Fame', '🌟', 'Top mentor for 4 weeks', false, 0.0),
          ], isDark),
          const SizedBox(height: 80),
        ]),
      ),
    );
  }

  Widget _statCard(String label, String value, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06)),
      ),
      child: Column(children: [
        Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: AppColors.textSecondaryLight, fontSize: 12)),
      ]),
    );
  }

  Widget _section(BuildContext context, String title) {
    return Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold));
  }

  Widget _badgeRow(List<_Badge> badges, bool isDark) {
    return Row(children: badges.map((b) => Expanded(child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: GestureDetector(
        onTap: () => _showBadgeDetail(b, isDark),
        child: _badgeCard(b, isDark),
      ),
    ))).toList());
  }

  Widget _badgeCard(_Badge b, bool isDark) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: b.earned
            ? AppColors.warning.withValues(alpha: 0.4)
            : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06))),
        boxShadow: b.earned ? [BoxShadow(color: AppColors.warning.withValues(alpha: 0.15), blurRadius: 12, offset: const Offset(0, 4))] : [],
      ),
      child: Column(children: [
        Stack(children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: b.earned ? const LinearGradient(colors: [Color(0xFFF59E0B), Color(0xFFFBBF24)]) : null,
              color: b.earned ? null : (isDark ? AppColors.surfaceDark2 : Colors.grey.shade200),
            ),
            child: Center(child: Text(b.emoji, style: TextStyle(fontSize: 24, color: b.earned ? null : Colors.grey))),
          ),
          if (!b.earned && b.progress > 0) Positioned.fill(
            child: CircularProgressIndicator(
              value: b.progress, strokeWidth: 3,
              backgroundColor: Colors.transparent,
              valueColor: const AlwaysStoppedAnimation(AppColors.primary),
            ),
          ),
        ]),
        const SizedBox(height: 8),
        Text(b.name, style: TextStyle(
          fontSize: 11, fontWeight: FontWeight.w600,
          color: b.earned ? null : AppColors.textSecondaryLight,
        ), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
        if (!b.earned && b.progress > 0) ...[
          const SizedBox(height: 4),
          Text('${(b.progress * 100).toInt()}%', style: const TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.bold)),
        ],
      ]),
    );
  }

  void _showBadgeDetail(_Badge b, bool isDark) {
    // Detail shown inline via the card itself - could extend to bottom sheet
  }
}

class _Badge {
  final String name, emoji, description;
  final bool earned;
  final double progress;
  const _Badge(this.name, this.emoji, this.description, this.earned, this.progress);
}
