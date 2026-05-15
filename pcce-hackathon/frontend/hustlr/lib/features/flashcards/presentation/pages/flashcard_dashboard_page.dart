import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:hustlr/core/theme/app_colors.dart';
import 'package:hustlr/core/widgets/glass_card.dart';
import 'package:hustlr/core/widgets/gradient_card.dart';
import 'package:hustlr/features/flashcards/presentation/pages/deck_view_page.dart';
import 'package:hustlr/features/flashcards/presentation/pages/ai_generate_page.dart';
import 'package:hustlr/features/flashcards/presentation/pages/deck_share_page.dart';
import 'dart:math';

class FlashcardDashboardPage extends StatelessWidget {
  const FlashcardDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(title: const Text('Flashcards')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Daily review hero
          GradientCard(
            gradient: AppColors.primaryGradient,
            child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Today\'s Review', style: TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 4),
                const Text('12 / 20 cards', style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(children: [
                  _whiteBadge('🔥 8-day streak'),
                  const SizedBox(width: 8),
                  _whiteBadge('87% retention'),
                ]),
                const SizedBox(height: 10),
                LinearProgressIndicator(value: 0.6, backgroundColor: Colors.white24, valueColor: const AlwaysStoppedAnimation(AppColors.accent), borderRadius: BorderRadius.circular(4), minHeight: 6),
              ])),
              const SizedBox(width: 16),
              // Retention ring
              CustomPaint(size: const Size(70, 70), painter: _RetentionRingPainter(0.87)),
            ]),
          ),
          const SizedBox(height: 20),

          // Spaced repetition stats
          Row(children: [
            Expanded(child: _srCard('New', '8', AppColors.info, LucideIcons.plus, isDark)),
            const SizedBox(width: 8),
            Expanded(child: _srCard('Learning', '5', AppColors.warning, LucideIcons.refreshCcw, isDark)),
            const SizedBox(width: 8),
            Expanded(child: _srCard('Review', '12', AppColors.accentOrange, LucideIcons.clock, isDark)),
            const SizedBox(width: 8),
            Expanded(child: _srCard('Mastered', '48', AppColors.success, LucideIcons.checkCircle, isDark)),
          ]),
          const SizedBox(height: 24),

          // Your decks
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Your Decks', style: Theme.of(context).textTheme.titleLarge),
            GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DeckSharePage())),
              child: const Text('Share →', style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ]),
          const SizedBox(height: 14),
          _deckCard(context, 'Flutter Widgets', '48 cards', 0.92, 'Roadmap', '2h ago', AppColors.primary, isDark),
          const SizedBox(height: 10),
          _deckCard(context, 'Data Structures', '120 cards', 0.61, 'PDF Upload', '1d ago', AppColors.accentPurple, isDark),
          const SizedBox(height: 10),
          _deckCard(context, 'System Design', '35 cards', 0.40, 'AI Generated', '3d ago', AppColors.accentOrange, isDark),
          const SizedBox(height: 10),
          _deckCard(context, 'SQL Queries', '28 cards', 0.78, 'YouTube', 'Today', AppColors.accent, isDark),
          const SizedBox(height: 24),

          // Community decks
          Text('Community Decks', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 14),
          _communityDeck(context, 'FAANG Interview Prep', 'rohit_v', '3.2k uses', '4.8 ⭐', isDark),
          const SizedBox(height: 10),
          _communityDeck(context, 'ML Fundamentals', 'anjali_d', '1.8k uses', '4.6 ⭐', isDark),
          const SizedBox(height: 10),
          _communityDeck(context, 'React Hooks Mastery', 'sneha_j', '2.1k uses', '4.9 ⭐', isDark),
          const SizedBox(height: 80),
        ]),
      ),
      floatingActionButton: FloatingActionButton.extended(heroTag: null, 
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AiGeneratePage())),
        backgroundColor: AppColors.primary,
        label: const Text('Generate with AI', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        icon: const Icon(LucideIcons.sparkles, color: Colors.white),
      ),
    );
  }

  Widget _srCard(String label, String count, Color color, IconData icon, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(height: 6),
        Text(count, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: color)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: AppColors.textSecondaryLight, fontSize: 10)),
      ]),
    );
  }

  Widget _deckCard(BuildContext context, String title, String count, double mastery, String source, String lastStudied, Color color, bool isDark) {
    final sourceIcons = {'Roadmap': LucideIcons.map, 'PDF Upload': LucideIcons.fileText, 'AI Generated': LucideIcons.sparkles, 'YouTube': LucideIcons.play};
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DeckViewPage())),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06)),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(LucideIcons.layers, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 2),
            Row(children: [
              Text(count, style: const TextStyle(color: AppColors.textSecondaryLight, fontSize: 12)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(sourceIcons[source] ?? LucideIcons.layers, size: 10, color: color),
                  const SizedBox(width: 3),
                  Text(source, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w600)),
                ]),
              ),
              const SizedBox(width: 8),
              Text(lastStudied, style: const TextStyle(color: AppColors.textSecondaryLight, fontSize: 10)),
            ]),
            const SizedBox(height: 6),
            Row(children: [
              Expanded(child: LinearProgressIndicator(value: mastery, backgroundColor: color.withValues(alpha: 0.1), valueColor: AlwaysStoppedAnimation(color), borderRadius: BorderRadius.circular(3), minHeight: 5)),
              const SizedBox(width: 8),
              Text('${(mastery * 100).toInt()}%', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
            ]),
          ])),
          const SizedBox(width: 8),
          const Icon(LucideIcons.playCircle, color: AppColors.primary, size: 26),
        ]),
      ),
    );
  }

  Widget _communityDeck(BuildContext context, String title, String author, String uses, String rating, bool isDark) {
    return GlassCard(
      padding: const EdgeInsets.all(14), borderRadius: 12,
      child: Row(children: [
        const Icon(LucideIcons.users, color: AppColors.accent, size: 20),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          Row(children: [
            Text('by $author · $uses', style: const TextStyle(color: AppColors.textSecondaryLight, fontSize: 12)),
            const SizedBox(width: 6),
            Text(rating, style: const TextStyle(color: AppColors.warning, fontSize: 11, fontWeight: FontWeight.w600)),
          ]),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
          child: const Text('Clone', style: TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.bold)),
        ),
      ]),
    );
  }

  static Widget _whiteBadge(String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(8)),
    child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
  );
}

class _RetentionRingPainter extends CustomPainter {
  final double pct;
  _RetentionRingPainter(this.pct);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 6;
    canvas.drawCircle(center, radius, Paint()..color = Colors.white24..style = PaintingStyle.stroke..strokeWidth = 5);
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), -pi / 2, 2 * pi * pct, false,
      Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 5..strokeCap = StrokeCap.round);
    final tp = TextPainter(text: TextSpan(text: '${(pct * 100).toInt()}%', style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)), textDirection: TextDirection.ltr)..layout();
    tp.paint(canvas, Offset(center.dx - tp.width / 2, center.dy - tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _RetentionRingPainter old) => old.pct != pct;
}
