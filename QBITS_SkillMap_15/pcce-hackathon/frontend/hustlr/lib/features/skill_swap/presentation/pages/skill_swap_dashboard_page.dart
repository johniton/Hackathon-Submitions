import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:hustlr/core/theme/app_colors.dart';
import 'package:hustlr/core/app_session.dart';
import 'package:hustlr/features/skill_swap/data/skill_swap_provider.dart';
import 'package:hustlr/features/skill_swap/domain/models/skill_swap_models.dart';
import 'package:hustlr/features/skill_swap/presentation/pages/skill_swap_matching_page.dart';
import 'package:hustlr/features/skill_swap/presentation/pages/skill_swap_session_log_page.dart';
import 'package:hustlr/features/skill_swap/presentation/pages/session_booking_page.dart';

/// Standalone page wrapper — creates its own provider.
/// Use SkillSwapDashboardBody directly inside SkillSwapPage (shared provider).
class SkillSwapDashboardPage extends StatelessWidget {
  const SkillSwapDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) {
        final p = SkillSwapProvider();
        final s = AppSession.instance;
        p.init(
          userId: s.userId ?? '',
          name: s.userName ?? 'User',
          avatarInitials: s.avatarInitials ?? 'U',
        );
        return p;
      },
      child: const SkillSwapDashboardBody(),
    );
  }
}

class SkillSwapDashboardBody extends StatefulWidget {
  const SkillSwapDashboardBody({super.key});
  @override
  State<SkillSwapDashboardBody> createState() => _SkillSwapDashboardBodyState();
}

class _SkillSwapDashboardBodyState extends State<SkillSwapDashboardBody>
    with TickerProviderStateMixin {
  late AnimationController _heroCtrl;
  late AnimationController _pulseCtrl;
  late Animation<double> _fadeAnim;
  late Animation<double> _slideAnim;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _heroCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _fadeAnim = CurvedAnimation(parent: _heroCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<double>(begin: 40, end: 0).animate(CurvedAnimation(parent: _heroCtrl, curve: Curves.easeOutCubic));
    _pulseAnim = Tween<double>(begin: 0.95, end: 1.05).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _heroCtrl.forward();
  }

  @override
  void dispose() {
    _heroCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<SkillSwapProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (prov.loading && prov.myProfile == null) {
      return Scaffold(
        backgroundColor: isDark ? const Color(0xFF0A0F1E) : const Color(0xFFF0F4FF),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (prov.myProfile == null) {
      return Scaffold(
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Could not load your profile.'),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: prov.refresh, child: const Text('Retry')),
          ]),
        ),
      );
    }

    final me = prov.myProfile!;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0F1E) : const Color(0xFFF0F4FF),
      body: AnimatedBuilder(
        animation: _heroCtrl,
        builder: (_, child) => Opacity(
          opacity: _fadeAnim.value,
          child: Transform.translate(offset: Offset(0, _slideAnim.value), child: child),
        ),
        child: RefreshIndicator(
          onRefresh: prov.refresh,
          child: CustomScrollView(
            slivers: [
              _buildHeroHeader(isDark, me, prov),
              if (prov.activeSwaps.isNotEmpty)
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _buildActiveSwapCard(prov, prov.activeSwaps[index], isDark),
                    childCount: prov.activeSwaps.length,
                  ),
                ),
              SliverToBoxAdapter(child: _buildSectionLabel('🎯  Top Matches for You', isDark, action: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => SkillSwapMatchingPage(provider: prov)));
              })),
              SliverToBoxAdapter(child: prov.suggestedMatches.isEmpty
                  ? _buildEmptyMatches(isDark)
                  : _buildSwipeMatchCards(prov.suggestedMatches, prov, isDark)),
              SliverToBoxAdapter(child: _buildSectionLabel('🏅  Achievements', isDark)),
              SliverToBoxAdapter(child: _buildBadgesRow(prov.badges, isDark)),
              SliverToBoxAdapter(child: _buildSectionLabel('💡  Your Skills', isDark)),
              SliverToBoxAdapter(child: _buildSkillsSection(me, isDark)),
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        ),
      ),
      floatingActionButton: _buildFAB(),
    );
  }

  Widget _buildHeroHeader(bool isDark, SkillSwapUser me, SkillSwapProvider prov) {
    return SliverToBoxAdapter(
      child: Stack(children: [
        Container(
          height: 280,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [Color(0xFF1A1060), Color(0xFF0D9488), Color(0xFF4F46E5)],
              stops: [0.0, 0.5, 1.0],
            ),
          ),
        ),
        Positioned(top: -40, right: -40, child: AnimatedBuilder(
          animation: _pulseAnim,
          builder: (_, __) => Transform.scale(
            scale: _pulseAnim.value,
            child: Container(width: 200, height: 200,
              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.05))),
          ),
        )),
        Positioned(bottom: 20, left: -30, child: Container(width: 150, height: 150,
          decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.accent.withValues(alpha: 0.15)))),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(20)),
                    child: const Row(children: [
                      Icon(LucideIcons.zap, size: 12, color: Colors.white),
                      SizedBox(width: 4),
                      Text('Skill Swap', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                    ]),
                  ),
                  const SizedBox(height: 8),
                  const Text('Exchange Skills,\nGrow Together',
                    style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold, height: 1.2)),
                ]),
                GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SkillSwapSessionLogPage())),
                  child: Stack(children: [
                    Container(width: 48, height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.3))),
                      child: const Icon(LucideIcons.calendarDays, color: Colors.white, size: 22)),
                    if (prov.pendingRatingsCount > 0)
                      Positioned(top: 0, right: 0, child: Container(
                        width: 16, height: 16,
                        decoration: const BoxDecoration(color: AppColors.warning, shape: BoxShape.circle),
                        child: Center(child: Text('${prov.pendingRatingsCount}',
                          style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold))),
                      )),
                  ]),
                ),
              ]),
              const SizedBox(height: 24),
              Row(children: [
                _heroStat('${me.sessionsCompleted}', 'Sessions', LucideIcons.refreshCcw),
                const SizedBox(width: 12),
                _heroStat('${me.rating}★', 'Rating', LucideIcons.star),
                const SizedBox(width: 12),
                _heroStat('${prov.suggestedMatches.length}', 'Matches', LucideIcons.users),
              ]),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _heroStat(String value, String label, IconData icon) {
    return Expanded(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2))),
            child: Column(children: [
              Icon(icon, color: Colors.white70, size: 16),
              const SizedBox(height: 4),
              Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
              Text(label, style: const TextStyle(color: Colors.white60, fontSize: 10)),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _buildActiveSwapCard(SkillSwapProvider prov, SwapMatch match, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF0D9488), Color(0xFF14B8A6)],
            begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: AppColors.accent.withValues(alpha: 0.35), blurRadius: 20, offset: const Offset(0, 8))],
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.25), borderRadius: BorderRadius.circular(20)),
                child: const Text('🔥  Active Swap', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))),
              const Spacer(),
              GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SkillSwapSessionLogPage())),
                child: const Text('View Sessions →', style: TextStyle(color: Colors.white70, fontSize: 12))),
            ]),
            const SizedBox(height: 14),
            Row(children: [
              CircleAvatar(radius: 22, backgroundColor: Colors.white.withValues(alpha: 0.25),
                child: Text(match.peer.avatar, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16))),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(match.peer.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                Text('${match.teachingSkill} ↔ ${match.learningSkill}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ])),
              ElevatedButton.icon(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SessionBookingPage(match: match, prov: prov))),
                icon: const Icon(LucideIcons.calendarPlus, size: 14),
                label: const Text('Book'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _buildEmptyMatches(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.15))),
        child: Column(children: [
          Icon(LucideIcons.users, size: 40, color: AppColors.primary.withValues(alpha: 0.4)),
          const SizedBox(height: 12),
          const Text('No matches yet', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 6),
          const Text('Add your skills below to find people to swap with!',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondaryLight, fontSize: 12)),
        ]),
      ),
    );
  }

  Widget _buildSwipeMatchCards(List<SwapMatch> matches, SkillSwapProvider prov, bool isDark) {
    return SizedBox(
      height: 240,
      child: PageView.builder(
        controller: PageController(viewportFraction: 0.85),
        padEnds: false,
        itemCount: matches.length,
        itemBuilder: (_, i) {
          final m = matches[i];
          final pct = (m.matchScore * 100).toInt();
          return Padding(
            padding: EdgeInsets.only(left: i == 0 ? 20 : 8, right: 8),
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(22),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08), blurRadius: 20, offset: const Offset(0, 8))],
                border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04))),
              padding: const EdgeInsets.all(18),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  CircleAvatar(radius: 24, backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                    child: Text(m.peer.avatar, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 18))),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(m.peer.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    Text(m.peer.city, style: const TextStyle(color: AppColors.textSecondaryLight, fontSize: 12)),
                  ])),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(gradient: pct >= 90 ? AppColors.tealGradient : AppColors.primaryGradient, borderRadius: BorderRadius.circular(20)),
                    child: Text('$pct%', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
                ]),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(12)),
                  child: Row(children: [
                    Expanded(child: _exchangeSide(LucideIcons.upload, 'You teach', m.teachingSkill, AppColors.primary)),
                    Container(width: 1, height: 32, color: Colors.grey.withValues(alpha: 0.2)),
                    Expanded(child: _exchangeSide(LucideIcons.download, 'You learn', m.learningSkill, AppColors.accent)),
                  ]),
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: _outlineBtn('Skip', () async {
                    HapticFeedback.lightImpact();
                    await prov.skipMatch(m);
                  })),
                  const SizedBox(width: 10),
                  Expanded(flex: 2, child: _gradientBtn('Connect', () async {
                    HapticFeedback.mediumImpact();
                    await prov.connectMatch(m);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Connected with ${m.peer.name}! 🎉'), behavior: SnackBarBehavior.floating));
                    }
                  })),
                ]),
              ]),
            ),
          );
        },
      ),
    );
  }

  Widget _exchangeSide(IconData icon, String label, String skill, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 11, color: color.withValues(alpha: 0.7)),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 10, color: color.withValues(alpha: 0.7))),
        ]),
        const SizedBox(height: 2),
        Text(skill, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color)),
      ]),
    );
  }

  Widget _buildBadgesRow(List<SwapBadge> badges, bool isDark) {
    if (badges.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 120,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(left: 20, right: 12),
        itemCount: badges.length,
        itemBuilder: (_, i) {
          final b = badges[i];
          return Opacity(
            opacity: b.earned ? 1.0 : 0.4,
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Container(
                width: 100, padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [BoxShadow(color: b.earned ? b.color.withValues(alpha: 0.2) : Colors.transparent, blurRadius: 12, offset: const Offset(0, 4))],
                  border: Border.all(color: b.earned ? b.color.withValues(alpha: 0.4) : Colors.grey.withValues(alpha: 0.15))),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(b.icon, color: b.color, size: 28),
                  const SizedBox(height: 6),
                  Text(b.title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                ]),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSkillsSection(SkillSwapUser me, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06), blurRadius: 16, offset: const Offset(0, 6))]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _skillGroup('Offering', me.skillsToOffer, AppColors.primary, me),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),
          _skillGroup('Want to Learn', me.skillsWanted, AppColors.accentOrange, me),
        ]),
      ),
    );
  }

  Widget _skillGroup(String title, List<String> skills, Color color, SkillSwapUser me) {
    final prov = context.read<SkillSwapProvider>();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(width: 4, height: 16, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color)),
      ]),
      const SizedBox(height: 10),
      Wrap(spacing: 8, runSpacing: 8, children: [
        ...skills.map((s) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.25))),
          child: Text(s, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
        )),
        GestureDetector(
          onTap: () => _showAddSkillDialog(prov, me, title == 'Offering'),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.withValues(alpha: 0.3))),
            child: Text('+ Add', style: TextStyle(color: Colors.grey.shade500, fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        ),
      ]),
    ]);
  }

  void _showAddSkillDialog(SkillSwapProvider prov, SkillSwapUser me, bool isOffering) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(isOffering ? 'Add a skill you offer' : 'Add a skill you want'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(
            hintText: isOffering ? 'e.g. Flutter, Python...' : 'e.g. React, UI/UX...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () async {
              final skill = ctrl.text.trim();
              if (skill.isEmpty) return;
              Navigator.pop(context);
              final newOffer = isOffering ? [...me.skillsToOffer, skill] : me.skillsToOffer;
              final newWant  = isOffering ? me.skillsWanted : [...me.skillsWanted, skill];
              await prov.updateSkills(skillsToOffer: newOffer, skillsWanted: newWant);
            },
            child: const Text('Add', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String title, bool isDark, {VoidCallback? action}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16,
          color: isDark ? Colors.white : const Color(0xFF0F172A))),
        if (action != null)
          GestureDetector(onTap: action,
            child: const Text('See all →', style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600))),
      ]),
    );
  }

  Widget _buildFAB() {
    return FloatingActionButton.extended(
      onPressed: () {
        HapticFeedback.mediumImpact();
        Navigator.push(context, MaterialPageRoute(builder: (_) => const SkillSwapMatchingPage()));
      },
      backgroundColor: Colors.transparent, elevation: 0,
      label: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(30),
          boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.4), blurRadius: 16, offset: const Offset(0, 6))]),
        child: const Row(children: [
          Icon(LucideIcons.search, color: Colors.white, size: 18),
          SizedBox(width: 8),
          Text('Find My Match', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
        ]),
      ),
    );
  }

  Widget _outlineBtn(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.withValues(alpha: 0.3))),
        child: Center(child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondaryLight))),
      ),
    );
  }

  Widget _gradientBtn(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(10),
          boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 3))]),
        child: Center(child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))),
      ),
    );
  }
}
