import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:hustlr/core/theme/app_colors.dart';
import 'package:hustlr/core/app_session.dart';
import 'package:hustlr/core/widgets/glass_card.dart';
import 'package:hustlr/features/skill_swap/data/skill_swap_provider.dart';
import 'package:hustlr/features/skill_swap/domain/models/skill_swap_models.dart';


class SkillSwapMatchingPage extends StatelessWidget {
  /// Optionally pass an existing provider from the dashboard.
  final SkillSwapProvider? provider;
  const SkillSwapMatchingPage({super.key, this.provider});

  @override
  Widget build(BuildContext context) {
    if (provider != null) {
      return ChangeNotifierProvider<SkillSwapProvider>.value(
        value: provider!,
        child: const SkillSwapMatchingBody(),
      );
    }
    return ChangeNotifierProvider(
      create: (_) {
        final p = SkillSwapProvider();
        final s = AppSession.instance;
        p.init(userId: s.userId ?? '', name: s.userName ?? 'User', avatarInitials: s.avatarInitials ?? 'U');
        return p;
      },
      child: const SkillSwapMatchingBody(),
    );
  }
}

class SkillSwapMatchingBody extends StatelessWidget {
  const SkillSwapMatchingBody();

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<SkillSwapProvider>();
    final me = prov.myProfile;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Find Matches'),
        actions: [
          IconButton(
            icon: prov.loading
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(LucideIcons.refreshCcw),
            onPressed: prov.refresh,
            tooltip: 'Refresh matches',
          ),
        ],
      ),
      body: me == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // ── Exchange profile ──────────────────────────────────────────
                Text('Your Exchange Profile', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 14),
                GlassCard(
                  padding: const EdgeInsets.all(16), borderRadius: 14,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    _prefRow('I can teach:', me.skillsToOffer.isEmpty ? 'None added yet' : me.skillsToOffer.join(', '),
                      LucideIcons.penTool, AppColors.primary, isDark),
                    const Divider(height: 24),
                    _prefRow('I want to learn:', me.skillsWanted.isEmpty ? 'None added yet' : me.skillsWanted.join(', '),
                      LucideIcons.graduationCap, AppColors.accent, isDark),
                    const Divider(height: 24),
                    _prefRow('Session type:', 'Video call (30–60 min)',
                      LucideIcons.video, AppColors.accentPurple, isDark),
                  ]),
                ),
                const SizedBox(height: 24),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('Top Matches', style: Theme.of(context).textTheme.titleLarge),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(20)),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(LucideIcons.sparkles, size: 12, color: Colors.white),
                      SizedBox(width: 4),
                      Text('AI-powered', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                    ]),
                  ),
                ]),
                const SizedBox(height: 14),
                if (prov.loading)
                  const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()))
                else if (prov.suggestedMatches.isEmpty)
                  _buildNoMatches(context, me.skillsToOffer.isEmpty || me.skillsWanted.isEmpty)
                else
                  ...prov.suggestedMatches.map((m) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _MatchDetailCard(match: m, isDark: isDark, prov: prov),
                  )),
              ]),
            ),
    );
  }

  Widget _buildNoMatches(BuildContext context, bool missingSkills) {
    return GlassCard(
      padding: const EdgeInsets.all(24), borderRadius: 16,
      child: Column(children: [
        Icon(LucideIcons.searchX, size: 40, color: AppColors.textSecondaryLight.withValues(alpha: 0.5)),
        const SizedBox(height: 12),
        Text(missingSkills ? 'Add your skills first!' : 'No matches found yet',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 6),
        Text(missingSkills
          ? 'Go to the dashboard and add skills you offer and skills you want to learn.'
          : 'Check back later as more users join. Try adding more skills!',
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textSecondaryLight, fontSize: 12)),
      ]),
    );
  }

  Widget _prefRow(String label, String value, IconData icon, Color color, bool isDark) {
    return Row(children: [
      Container(padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: color, size: 18)),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(color: AppColors.textSecondaryLight, fontSize: 11)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      ])),
    ]);
  }
}

// ─── Match detail card ────────────────────────────────────────────────────────

class _MatchDetailCard extends StatelessWidget {
  final SwapMatch match;
  final bool isDark;
  final SkillSwapProvider prov;
  const _MatchDetailCard({required this.match, required this.isDark, required this.prov});

  @override
  Widget build(BuildContext context) {
    final pct = (match.matchScore * 100).toInt();
    final barColor = pct >= 90 ? AppColors.success : pct >= 75 ? AppColors.warning : AppColors.info;

    return GlassCard(
      padding: const EdgeInsets.all(16), borderRadius: 16,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(radius: 26, backgroundColor: AppColors.primary.withValues(alpha: 0.12),
            child: Text(match.peer.avatar, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 18))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(match.peer.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            Text('${match.peer.city} · ${match.peer.sessionsCompleted} sessions',
              style: const TextStyle(color: AppColors.textSecondaryLight, fontSize: 12)),
            Row(children: [
              const Icon(LucideIcons.star, size: 12, color: AppColors.warning),
              const SizedBox(width: 3),
              Text(match.peer.rating.toStringAsFixed(1),
                style: const TextStyle(color: AppColors.textSecondaryLight, fontSize: 12)),
            ]),
          ])),
          Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: barColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
            child: Text('$pct% match', style: TextStyle(color: barColor, fontWeight: FontWeight.bold, fontSize: 12))),
        ]),
        const SizedBox(height: 12),
        ClipRRect(borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(value: match.matchScore, minHeight: 6,
            backgroundColor: Colors.grey.withValues(alpha: 0.15),
            valueColor: AlwaysStoppedAnimation(barColor))),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(10)),
          child: Row(children: [
            Expanded(child: _exchangeChip(LucideIcons.upload, 'You teach', match.teachingSkill, AppColors.primary)),
            const Padding(padding: EdgeInsets.symmetric(horizontal: 8),
              child: Icon(LucideIcons.arrowLeftRight, size: 16, color: AppColors.textSecondaryLight)),
            Expanded(child: _exchangeChip(LucideIcons.download, 'You learn', match.learningSkill, AppColors.accent)),
          ]),
        ),
        const SizedBox(height: 10),
        Wrap(spacing: 6, runSpacing: 6,
          children: match.peer.skillsToOffer.map((s) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
            child: Text(s, style: const TextStyle(fontSize: 11, color: AppColors.accent, fontWeight: FontWeight.w600)),
          )).toList()),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () async {
                HapticFeedback.lightImpact();
                await prov.skipMatch(match);
                if (context.mounted) Navigator.pop(context);
              },
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: AppColors.textSecondaryLight.withValues(alpha: 0.5)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 10)),
              child: const Text('Skip', style: TextStyle(color: AppColors.textSecondaryLight, fontSize: 13)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(flex: 2,
            child: GestureDetector(
              onTap: () async {
                HapticFeedback.mediumImpact();
                await prov.connectMatch(match);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('✅ Connected with ${match.peer.name}! Book a session from your dashboard.'),
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 3),
                    ),
                  );
                  Navigator.pop(context); // Go back to dashboard
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 11),
                decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(10)),
                child: const Center(child: Text('Connect',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13))),
              ),
            ),
          ),
        ]),
      ]),
    );
  }

  Widget _exchangeChip(IconData icon, String label, String skill, Color color) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 10, color: color.withValues(alpha: 0.7))),
      ]),
      const SizedBox(height: 2),
      Text(skill, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color)),
    ]);
  }
}
