import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:hustlr/core/theme/app_colors.dart';
import 'package:hustlr/core/widgets/glass_card.dart';
import 'package:hustlr/core/widgets/gradient_card.dart';
import 'dart:math';

class ChallengesPage extends StatefulWidget {
  const ChallengesPage({super.key});
  @override
  State<ChallengesPage> createState() => _ChallengesPageState();
}

class _ChallengesPageState extends State<ChallengesPage> with SingleTickerProviderStateMixin {
  late AnimationController _timerCtrl;

  @override
  void initState() {
    super.initState();
    _timerCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 60))..repeat();
  }

  @override
  void dispose() { _timerCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(title: const Text('Challenges')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Timer card
          GradientCard(
            gradient: AppColors.primaryGradient,
            child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Weekly Reset', style: TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 4),
                const Text('3d 14h 22m', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text('Complete challenges before reset to earn bonus XP!', style: TextStyle(color: Colors.white70, fontSize: 12)),
              ])),
              AnimatedBuilder(
                animation: _timerCtrl,
                builder: (_, __) => CustomPaint(
                  size: const Size(70, 70),
                  painter: _TimerPainter(_timerCtrl.value),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 24),

          // Weekly challenges
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Weekly Challenges', style: Theme.of(context).textTheme.titleLarge),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
              child: const Text('3/5 done', style: TextStyle(color: AppColors.warning, fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ]),
          const SizedBox(height: 14),

          _weeklyChallenge(isDark, 'Complete 2 Mock Interviews', 'Ace your interview skills with AI practice', LucideIcons.mic, 2, 2, 200, AppColors.primaryGradient, true),
          const SizedBox(height: 12),
          _weeklyChallenge(isDark, 'Help 3 People with Answers', 'Answer questions in the community Q&A', LucideIcons.messageCircle, 2, 3, 150, AppColors.tealGradient, false),
          const SizedBox(height: 12),
          _weeklyChallenge(isDark, '7-Day Coding Streak', 'Code every day for a week straight', LucideIcons.flame, 5, 7, 500, AppColors.orangeGradient, false),
          const SizedBox(height: 12),
          _weeklyChallenge(isDark, 'Review 20 Flashcards', 'Keep your spaced repetition on track', LucideIcons.layers, 20, 20, 100, AppColors.purpleGradient, true),
          const SizedBox(height: 12),
          _weeklyChallenge(isDark, 'Score 90+ on ATS Analyzer', 'Polish your resume to perfection', LucideIcons.fileCheck, 1, 1, 300, AppColors.primaryGradient, true),
          const SizedBox(height: 28),

          // Sponsored challenges
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Sponsored Challenges', style: Theme.of(context).textTheme.titleLarge),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: AppColors.accentPurple.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(LucideIcons.sparkles, size: 12, color: AppColors.accentPurple),
                SizedBox(width: 4),
                Text('Real Hiring', style: TextStyle(color: AppColors.accentPurple, fontSize: 11, fontWeight: FontWeight.bold)),
              ]),
            ),
          ]),
          const SizedBox(height: 14),

          _sponsoredChallenge(isDark, 'Build with Firebase', 'Google', '🏆 ₹10,000 + Offer Letter', 'Build a real-time app using Firebase services. Top performers get direct interview access.', 342, 'Hard', '5 days left'),
          const SizedBox(height: 12),
          _sponsoredChallenge(isDark, 'Design System Sprint', 'Razorpay', '🏅 Summer Internship', 'Create a complete design system in Flutter. Showcase your UI/UX skills.', 189, 'Medium', '12 days left'),
          const SizedBox(height: 12),
          _sponsoredChallenge(isDark, 'API Hackathon', 'Postman', '💰 ₹25,000 + Swag Kit', 'Build creative APIs and document them. Best APIs win cash prizes.', 567, 'Medium', '8 days left'),
          const SizedBox(height: 80),
        ]),
      ),
    );
  }

  Widget _weeklyChallenge(bool isDark, String title, String desc, IconData icon, int progress, int total, int xp, LinearGradient gradient, bool done) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: done ? AppColors.success.withValues(alpha: 0.3) : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06))),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(gradient: gradient, borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
              if (done) Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(LucideIcons.checkCircle, size: 12, color: AppColors.success),
                  SizedBox(width: 4),
                  Text('Done', style: TextStyle(color: AppColors.success, fontSize: 10, fontWeight: FontWeight.bold)),
                ]),
              ),
            ]),
            const SizedBox(height: 2),
            Text(desc, style: TextStyle(color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight, fontSize: 12)),
          ])),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: progress / total),
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOutCubic,
              builder: (_, v, __) => LinearProgressIndicator(
                value: v, backgroundColor: gradient.colors.first.withValues(alpha: 0.1),
                valueColor: AlwaysStoppedAnimation(done ? AppColors.success : gradient.colors.first), minHeight: 7,
              ),
            ),
          )),
          const SizedBox(width: 12),
          Text('$progress/$total', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(LucideIcons.zap, size: 12, color: AppColors.warning),
              const SizedBox(width: 3),
              Text('+$xp XP', style: const TextStyle(color: AppColors.warning, fontWeight: FontWeight.bold, fontSize: 11)),
            ]),
          ),
        ]),
      ]),
    );
  }

  Widget _sponsoredChallenge(bool isDark, String title, String sponsor, String prize, String desc, int participants, String difficulty, String deadline) {
    final diffColor = difficulty == 'Hard' ? AppColors.error : AppColors.warning;
    return GlassCard(
      padding: const EdgeInsets.all(16), borderRadius: 16,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(color: AppColors.accentPurple.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
            child: const Icon(LucideIcons.trophy, color: AppColors.accentPurple, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            Row(children: [
              Text('by $sponsor', style: const TextStyle(color: AppColors.textSecondaryLight, fontSize: 12)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: diffColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                child: Text(difficulty, style: TextStyle(color: diffColor, fontSize: 9, fontWeight: FontWeight.bold)),
              ),
            ]),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(LucideIcons.briefcase, size: 10, color: AppColors.success),
              SizedBox(width: 3),
              Text('Real Hiring', style: TextStyle(color: AppColors.success, fontSize: 9, fontWeight: FontWeight.bold)),
            ]),
          ),
        ]),
        const SizedBox(height: 10),
        Text(desc, style: TextStyle(color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight, fontSize: 13, height: 1.4)),
        const SizedBox(height: 12),
        Row(children: [
          Text(prize, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.success)),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          _infoChip(LucideIcons.users, '$participants joined'),
          const SizedBox(width: 10),
          _infoChip(LucideIcons.clock, deadline),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(10)),
            child: const Text('Join Challenge', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ]),
      ]),
    );
  }

  Widget _infoChip(IconData icon, String text) => Row(mainAxisSize: MainAxisSize.min, children: [
    Icon(icon, size: 12, color: AppColors.textSecondaryLight),
    const SizedBox(width: 4),
    Text(text, style: const TextStyle(color: AppColors.textSecondaryLight, fontSize: 11)),
  ]);
}

class _TimerPainter extends CustomPainter {
  final double progress;
  _TimerPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;
    canvas.drawCircle(center, radius, Paint()..color = Colors.white24..style = PaintingStyle.stroke..strokeWidth = 4);
    final arc = Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 4..strokeCap = StrokeCap.round;
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), -pi / 2, 2 * pi * (1 - progress), false, arc);
    final textPainter = TextPainter(text: const TextSpan(text: '⏱️', style: TextStyle(fontSize: 22)), textDirection: TextDirection.ltr)..layout();
    textPainter.paint(canvas, Offset(center.dx - textPainter.width / 2, center.dy - textPainter.height / 2));
  }

  @override
  bool shouldRepaint(covariant _TimerPainter old) => old.progress != progress;
}
