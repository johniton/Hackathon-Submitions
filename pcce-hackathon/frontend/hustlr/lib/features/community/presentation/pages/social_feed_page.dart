import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:hustlr/core/theme/app_colors.dart';
import 'package:hustlr/core/widgets/glass_card.dart';
import 'package:hustlr/features/community/presentation/pages/create_post_page.dart';
import 'package:hustlr/features/community/presentation/pages/puzzle_board_page.dart';
import 'package:hustlr/features/community/presentation/pages/ai_tech_feed_page.dart';

enum PostType { all, project, achievement, question, resource, hiring }

class SocialFeedPage extends StatefulWidget {
  const SocialFeedPage({super.key});
  @override
  State<SocialFeedPage> createState() => _SocialFeedPageState();
}

class _SocialFeedPageState extends State<SocialFeedPage> {
  PostType _filter = PostType.all;
  final Set<int> _liked = {};

  static const _authors = ['Anjali Desai','Rohit Verma','Sneha Joshi','Pranav Nair','TechCorp HR','Meera Kapoor'];
  static const _avatars = ['A','R','S','P','T','M'];
  static const _times = ['2h ago','4h ago','6h ago','8h ago','1d ago','1d ago'];
  static const _contents = [
    'Just deployed my first Flutter Web app! Check it out 🚀',
    'Cleared my Google L4 interview! AI Mock Interview helped a ton 🙌',
    'Riverpod vs BLoC — which do you prefer for complex state management?',
    'Free resource: 120-page System Design PDF covering all FAANG topics 📚',
    'We\'re hiring Flutter developers! Remote-first, competitive pay.',
    'Built a real-time chat app with WebSockets in Dart — sharing architecture.',
  ];
  static const _types = [PostType.project, PostType.achievement, PostType.question, PostType.resource, PostType.hiring, PostType.project];
  static const _badges = ['🏆 Top Contributor','⭐ Rising Star',null,'🎓 Certified',null,null];
  static const _likes = [42,128,19,76,34,55];
  static const _comments = [8,24,15,12,6,11];
  static const _karmas = [320,890,210,450,0,560];
  static const _tagsList = [
    ['Flutter','Firebase','Web'],['Google','DSA'],['Flutter','Architecture'],
    ['System Design','FAANG'],['Flutter','Remote'],['Dart','WebSocket'],
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final indices = List.generate(6, (i) => i);
    final filtered = _filter == PostType.all ? indices : indices.where((i) => _types[i] == _filter).toList();

    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Community', style: Theme.of(context).textTheme.headlineLarge),
              Row(children: [
                _iconBtn(LucideIcons.bell, AppColors.primary),
                const SizedBox(width: 8),
                _iconBtn(LucideIcons.search, AppColors.accent),
              ]),
            ]),
          ),
          // ── XP Bar ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: GlassCard(
              padding: const EdgeInsets.all(14), borderRadius: 14,
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFF59E0B), Color(0xFFFBBF24)]), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(LucideIcons.zap, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text('Level 7 · 3,240 XP', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(LucideIcons.flame, size: 14, color: AppColors.accentOrange),
                      const SizedBox(width: 3),
                      const Text('12 day streak', style: TextStyle(color: AppColors.accentOrange, fontSize: 11, fontWeight: FontWeight.w600)),
                    ]),
                  ]),
                  const SizedBox(height: 6),
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 0.81), duration: const Duration(milliseconds: 1200), curve: Curves.easeOutCubic,
                    builder: (_, v, __) => LinearProgressIndicator(value: v, backgroundColor: AppColors.warning.withValues(alpha: 0.15), valueColor: const AlwaysStoppedAnimation(AppColors.warning), borderRadius: BorderRadius.circular(4), minHeight: 7),
                  ),
                  const SizedBox(height: 4),
                  const Text('760 XP to Level 8', style: TextStyle(color: AppColors.textSecondaryLight, fontSize: 11)),
                ])),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          // ── Puzzle Board Banner ─────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PuzzleBoardPage())),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: AppColors.purpleGradient,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.25), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: Row(children: [
                  const Text('🪐', style: TextStyle(fontSize: 24)),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
                    Text('Solar System Puzzle', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                    Text('Unlock planets & build your galaxy', style: TextStyle(color: Colors.white70, fontSize: 11)),
                  ])),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10)),
                    child: const Text('Open', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ]),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Filter tabs
          SizedBox(
            height: 40,
            child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 20), children: [
              _chip(PostType.all, 'All', LucideIcons.layoutGrid, isDark),
              _chip(PostType.project, 'Projects', LucideIcons.rocket, isDark),
              _chip(PostType.achievement, 'Wins', LucideIcons.trophy, isDark),
              _chip(PostType.question, 'Q&A', LucideIcons.helpCircle, isDark),
              _chip(PostType.resource, 'Resources', LucideIcons.bookOpen, isDark),
              _chip(PostType.hiring, 'Hiring', LucideIcons.briefcase, isDark),
            ]),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
              itemCount: filtered.length, separatorBuilder: (_, __) => const SizedBox(height: 14),
              itemBuilder: (_, idx) => _postCard(filtered[idx], isDark),
            ),
          ),
        ]),
      ),
      floatingActionButton: FloatingActionButton(heroTag: null, 
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreatePostPage())),
        backgroundColor: AppColors.primary,
        child: const Icon(LucideIcons.plus, color: Colors.white),
      ),
    );
  }

  Widget _chip(PostType type, String label, IconData icon, bool isDark) {
    final sel = _filter == type;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => setState(() => _filter = type),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            gradient: sel ? AppColors.primaryGradient : null,
            color: sel ? null : AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(20),
            border: sel ? null : Border.all(color: const Color(0xFFE8DDD2)),
            boxShadow: sel ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.25), blurRadius: 8, offset: const Offset(0, 3))] : null,
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 14, color: sel ? Colors.white : AppColors.textSecondaryLight),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: sel ? Colors.white : AppColors.textSecondaryLight, fontSize: 12, fontWeight: FontWeight.w600)),
          ]),
        ),
      ),
    );
  }

  Widget _postCard(int i, bool isDark) {
    final liked = _liked.contains(i);
    final typeColor = [AppColors.primary, AppColors.warning, AppColors.info, AppColors.accent, AppColors.accentPurple, AppColors.primary][i];
    final typeLabel = ['🚀 PROJECT','🏆 WIN','❓ Q&A','📚 RESOURCE','💼 HIRING','🚀 PROJECT'][i];

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8DDD2)),
        boxShadow: [BoxShadow(color: const Color(0xFFC4B5A0).withValues(alpha: 0.1), blurRadius: 14, offset: const Offset(0, 5))],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Author row
      Row(children: [
        Stack(children: [
          CircleAvatar(radius: 22, backgroundColor: typeColor.withValues(alpha: 0.15),
            child: Text(_avatars[i], style: TextStyle(color: typeColor, fontWeight: FontWeight.bold, fontSize: 16))),
          if (_karmas[i] > 0) Positioned(bottom: -2, right: -2, child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: AppColors.warning, shape: BoxShape.circle, border: Border.all(color: AppColors.surfaceLight, width: 2)),
            child: const Icon(LucideIcons.star, size: 8, color: Colors.white),
          )),
        ]),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(_authors[i], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            if (_badges[i] != null) ...[const SizedBox(width: 6), Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
              child: Text(_badges[i]!, style: const TextStyle(fontSize: 9, color: AppColors.warning, fontWeight: FontWeight.w600)),
            )],
          ]),
          Row(children: [
            Text(_times[i], style: const TextStyle(color: AppColors.textSecondaryLight, fontSize: 12)),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(color: typeColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
              child: Text(typeLabel, style: TextStyle(color: typeColor, fontSize: 9, fontWeight: FontWeight.w700)),
            ),
          ]),
        ])),
        const Icon(LucideIcons.moreHorizontal, size: 18, color: AppColors.textSecondaryLight),
      ]),
      const SizedBox(height: 12),
      Text(_contents[i], style: const TextStyle(fontSize: 14, height: 1.5, color: AppColors.textPrimaryLight)),
      const SizedBox(height: 10),
      Wrap(spacing: 6, runSpacing: 4, children: _tagsList[i].map((t) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(6)),
        child: Text('#$t', style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w600)),
      )).toList()),
      const SizedBox(height: 14),
      // Divider
      const Divider(color: Color(0xFFEBE3D8), height: 1),
      const SizedBox(height: 10),
      // Actions
      Row(children: [
        GestureDetector(
          onTap: () => setState(() => liked ? _liked.remove(i) : _liked.add(i)),
          child: _actionBtn(LucideIcons.heart, '${_likes[i] + (liked ? 1 : 0)}', liked ? AppColors.accentPink : AppColors.textSecondaryLight),
        ),
        const SizedBox(width: 18),
        _actionBtn(LucideIcons.messageCircle, '${_comments[i]}', AppColors.primary),
        const SizedBox(width: 18),
        _actionBtn(LucideIcons.share2, 'Share', AppColors.accent),
        const Spacer(),
        const Icon(LucideIcons.bookmark, size: 16, color: AppColors.textSecondaryLight),
      ]),
    ]));
  }

  Widget _iconBtn(IconData icon, Color color) => Container(
    padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
    child: Icon(icon, color: color, size: 18),
  );

  Widget _actionBtn(IconData icon, String label, Color color) => Row(children: [
    Icon(icon, color: color, size: 16), const SizedBox(width: 5),
    Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
  ]);
}
