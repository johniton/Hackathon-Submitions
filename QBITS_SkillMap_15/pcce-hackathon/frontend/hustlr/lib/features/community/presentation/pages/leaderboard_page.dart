import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:hustlr/core/theme/app_colors.dart';
import 'package:hustlr/core/widgets/glass_card.dart';
import 'package:hustlr/core/widgets/gradient_card.dart';

class LeaderboardPage extends StatefulWidget {
  const LeaderboardPage({super.key});
  @override
  State<LeaderboardPage> createState() => _LeaderboardPageState();
}

class _LeaderboardPageState extends State<LeaderboardPage> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  int _sortBy = 0; // 0=XP, 1=Karma, 2=Streak

  @override
  void initState() { super.initState(); _tabCtrl = TabController(length: 4, vsync: this); _tabCtrl.addListener(() => setState(() {})); }
  @override
  void dispose() { _tabCtrl.dispose(); super.dispose(); }

  static const _allUsers = [
    {'name': 'Rohit Verma', 'xp': 12450, 'karma': 890, 'streak': 28, 'college': 'IIT Bombay', 'city': 'Mumbai', 'stack': 'Flutter', 'trend': 1},
    {'name': 'Anjali Desai', 'xp': 11200, 'karma': 1200, 'streak': 21, 'college': 'IIT Bombay', 'city': 'Bangalore', 'stack': 'React', 'trend': 0},
    {'name': 'Priya Sharma', 'xp': 10100, 'karma': 670, 'streak': 14, 'college': 'NIT Surat', 'city': 'Delhi', 'stack': 'Python', 'trend': 2},
    {'name': 'Karan Mehta', 'xp': 8750, 'karma': 980, 'streak': 35, 'college': 'IIT Bombay', 'city': 'Mumbai', 'stack': 'Flutter', 'trend': -1},
    {'name': 'Sneha Joshi', 'xp': 7980, 'karma': 540, 'streak': 10, 'college': 'BITS Pilani', 'city': 'Bangalore', 'stack': 'Node.js', 'trend': 1},
    {'name': 'Arjun Patel', 'xp': 7200, 'karma': 430, 'streak': 7, 'college': 'NIT Surat', 'city': 'Pune', 'stack': 'Flutter', 'trend': 0},
    {'name': 'Neha Gupta', 'xp': 6800, 'karma': 780, 'streak': 19, 'college': 'IIIT Hyderabad', 'city': 'Hyderabad', 'stack': 'React', 'trend': 3},
    {'name': 'Vikram Singh', 'xp': 6100, 'karma': 350, 'streak': 5, 'college': 'BITS Pilani', 'city': 'Delhi', 'stack': 'Python', 'trend': -2},
  ];

  List<Map<String, dynamic>> get _filtered {
    var list = List<Map<String, dynamic>>.from(_allUsers);
    final tab = _tabCtrl.index;
    if (tab == 1) list = list.where((u) => u['college'] == 'IIT Bombay').toList();
    if (tab == 2) list = list.where((u) => u['city'] == 'Mumbai' || u['city'] == 'Bangalore').toList();
    if (tab == 3) list = list.where((u) => u['stack'] == 'Flutter').toList();
    if (_sortBy == 1) { list.sort((a, b) => (b['karma'] as int).compareTo(a['karma'] as int)); }
    else if (_sortBy == 2) { list.sort((a, b) => (b['streak'] as int).compareTo(a['streak'] as int)); }
    else { list.sort((a, b) => (b['xp'] as int).compareTo(a['xp'] as int)); }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final users = _filtered;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Leaderboard'),
        bottom: TabBar(
          controller: _tabCtrl,
          isScrollable: true,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondaryLight,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [Tab(text: '🌍 Global'), Tab(text: '🎓 College'), Tab(text: '🏙️ City'), Tab(text: '💻 Tech Stack')],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          // Your rank card
          GradientCard(gradient: AppColors.orangeGradient, child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Your Rank', style: TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 4),
              const Text('#18', style: TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              const Text('3,240 XP · Top 10%', style: TextStyle(color: Colors.white, fontSize: 13)),
              const SizedBox(height: 8),
              Row(children: [
                _statBadge('🔥 12-day streak', Colors.white24),
                const SizedBox(width: 8),
                _statBadge('⭐ 320 Karma', Colors.white24),
              ]),
            ])),
            const Column(children: [
              Text('🏆', style: TextStyle(fontSize: 40)),
              SizedBox(height: 4),
              Text('Top 10%', style: TextStyle(color: Colors.white70, fontSize: 11)),
            ]),
          ])),
          const SizedBox(height: 16),

          // Sort buttons
          Row(children: [
            _sortChip(0, 'XP', isDark),
            const SizedBox(width: 8),
            _sortChip(1, 'Karma', isDark),
            const SizedBox(width: 8),
            _sortChip(2, 'Streak', isDark),
          ]),
          const SizedBox(height: 16),

          // Top 3 podium
          if (users.length >= 3) ...[
            SizedBox(
              height: 180,
              child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Expanded(child: _podiumCard(users[1], 2, '🥈', 130, isDark)),
                const SizedBox(width: 8),
                Expanded(child: _podiumCard(users[0], 1, '🥇', 170, isDark)),
                const SizedBox(width: 8),
                Expanded(child: _podiumCard(users[2], 3, '🥉', 110, isDark)),
              ]),
            ),
            const SizedBox(height: 20),
          ],

          // Rest of the list
          ListView.separated(
            shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
            itemCount: users.length > 3 ? users.length - 3 : 0,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final u = users[i + 3];
              final trend = u['trend'] as int;
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE8DDD2)),
                  boxShadow: [BoxShadow(color: const Color(0xFFC4B5A0).withValues(alpha: 0.08), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: Row(children: [
                SizedBox(width: 32, child: Text('${i + 4}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                const SizedBox(width: 10),
                CircleAvatar(radius: 20, backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                  child: Text((u['name'] as String)[0], style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold))),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(u['name'] as String, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  Text('${_fmtNum(u['xp'] as int)} XP · ${u['karma']} karma', style: const TextStyle(color: AppColors.textSecondaryLight, fontSize: 11)),
                ])),
                if (trend != 0) Icon(trend > 0 ? LucideIcons.arrowUp : LucideIcons.arrowDown, size: 14, color: trend > 0 ? AppColors.success : AppColors.error),
                if (trend != 0) const SizedBox(width: 2),
                if (trend != 0) Text('${trend.abs()}', style: TextStyle(color: trend > 0 ? AppColors.success : AppColors.error, fontSize: 11, fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                Row(children: [
                  const Icon(LucideIcons.zap, size: 14, color: AppColors.warning),
                  const SizedBox(width: 3),
                  Text(_fmtNum(u['xp'] as int), style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.warning, fontSize: 13)),
                ]),
              ]));
            },
          ),
        ]),
      ),
    );
  }

  Widget _podiumCard(Map<String, dynamic> u, int rank, String medal, double h, bool isDark) {
    final gradients = [AppColors.primaryGradient, AppColors.orangeGradient, AppColors.tealGradient];
    return Container(
      height: h,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        gradient: gradients[rank - 1],
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: gradients[rank - 1].colors.first.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 6))],
      ),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(medal, style: const TextStyle(fontSize: 28)),
        const SizedBox(height: 6),
        CircleAvatar(radius: 18, backgroundColor: Colors.white24,
          child: Text((u['name'] as String)[0], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16))),
        const SizedBox(height: 6),
        Text((u['name'] as String).split(' ').first, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12), overflow: TextOverflow.ellipsis),
        const SizedBox(height: 2),
        Text('${_fmtNum(u['xp'] as int)} XP', style: const TextStyle(color: Colors.white70, fontSize: 10)),
      ]),
    );
  }

  Widget _sortChip(int idx, String label, bool isDark) {
    final sel = _sortBy == idx;
    return GestureDetector(
      onTap: () => setState(() => _sortBy = idx),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: sel ? AppColors.primary : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(20),
          border: sel ? null : Border.all(color: const Color(0xFFE8DDD2)),
          boxShadow: sel ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.25), blurRadius: 8, offset: const Offset(0, 3))] : null,
        ),
        child: Text(label, style: TextStyle(color: sel ? Colors.white : AppColors.textSecondaryLight, fontSize: 12, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _statBadge(String text, Color bg) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
    child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
  );

  String _fmtNum(int n) => n >= 1000 ? '${(n / 1000).toStringAsFixed(1)}k' : '$n';
}
