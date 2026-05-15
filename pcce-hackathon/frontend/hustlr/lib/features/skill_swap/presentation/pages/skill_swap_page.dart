/// skill_swap_page.dart
///
/// Unified Skill Swap entry point with tab navigation.
/// ONE SkillSwapProvider is created here and shared across ALL tabs,
/// so data (matches, sessions, profile) never goes stale between tabs.

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:hustlr/core/app_session.dart';
import 'package:hustlr/core/theme/app_colors.dart';
import 'package:hustlr/features/skill_swap/data/skill_swap_provider.dart';
import 'package:hustlr/features/skill_swap/presentation/pages/skill_swap_dashboard_page.dart';
import 'package:hustlr/features/skill_swap/presentation/pages/skill_swap_matching_page.dart';
import 'package:hustlr/features/skill_swap/presentation/pages/session_booking_page.dart';

class SkillSwapPage extends StatefulWidget {
  const SkillSwapPage({super.key});

  @override
  State<SkillSwapPage> createState() => _SkillSwapPageState();
}

class _SkillSwapPageState extends State<SkillSwapPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late SkillSwapProvider _prov;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _prov = SkillSwapProvider();
    final s = AppSession.instance;
    _prov.init(
      userId: s.userId ?? '',
      name: s.userName ?? 'User',
      avatarInitials: s.avatarInitials ?? 'U',
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _prov.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<SkillSwapProvider>.value(
      value: _prov,
      child: Scaffold(
        // ── AppBar with integrated TabBar ──────────────────────────────────
        appBar: AppBar(
          title: Consumer<SkillSwapProvider>(
            builder: (_, prov, __) => Row(children: [
              const Text('Skill Swap'),
              if (prov.pendingRatingsCount > 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.warning.withValues(alpha: 0.5)),
                  ),
                  child: Text('${prov.pendingRatingsCount} to rate',
                    style: const TextStyle(color: AppColors.warning, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ],
            ]),
          ),
          actions: [
            Consumer<SkillSwapProvider>(
              builder: (_, prov, __) => IconButton(
                icon: prov.loading
                    ? const SizedBox(width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(LucideIcons.refreshCcw),
                onPressed: prov.refresh,
                tooltip: 'Refresh',
              ),
            ),
          ],
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: AppColors.accent,
            indicatorWeight: 3,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white54,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
            tabs: const [
              Tab(icon: Icon(LucideIcons.layoutDashboard, size: 16), text: 'Dashboard'),
              Tab(icon: Icon(LucideIcons.users, size: 16), text: 'Find Matches'),
              Tab(icon: Icon(LucideIcons.calendarPlus, size: 16), text: 'Book Session'),
            ],
          ),
        ),
        // ── Tab content ───────────────────────────────────────────────────
        body: TabBarView(
          controller: _tabController,
          children: const [
            SkillSwapDashboardBody(),   // tab 0
            SkillSwapMatchingBody(),    // tab 1
            SkillSwapBookingBody(),     // tab 2
          ],
        ),
      ),
    );
  }
}
