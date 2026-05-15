import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:hustlr/core/theme/app_colors.dart';

class SolarPiece {
  final int id;
  final String name;
  final String emoji;
  final String achievement;
  final double orbitRadius;
  final double angle;
  final Color color;
  final double size;
  bool unlocked;

  SolarPiece({
    required this.id,
    required this.name,
    required this.emoji,
    required this.achievement,
    required this.orbitRadius,
    required this.angle,
    required this.color,
    required this.size,
    this.unlocked = false,
  });
}

class PuzzleBoardPage extends StatefulWidget {
  const PuzzleBoardPage({super.key});
  @override
  State<PuzzleBoardPage> createState() => _PuzzleBoardPageState();
}

class _PuzzleBoardPageState extends State<PuzzleBoardPage> with TickerProviderStateMixin {
  late final List<SolarPiece> _allPieces;
  final Set<int> _placedIds = {};
  int _viewingUser = 0;

  static const _otherUsers = [
    {'name': 'Rohit', 'initial': 'R', 'placed': 4, 'color': 0xFFEF4444},
    {'name': 'Anjali', 'initial': 'A', 'placed': 8, 'color': 0xFFF59E0B},
  ];

  @override
  void initState() {
    super.initState();
    _allPieces = [
      SolarPiece(id: 0, name: 'Sun', emoji: '☀️', achievement: 'First Post 📝', orbitRadius: 0, angle: 0, color: const Color(0xFFFFD166), size: 50, unlocked: true),
      SolarPiece(id: 1, name: 'Mercury', emoji: '🪨', achievement: '5 Likes ❤️', orbitRadius: 40, angle: 0.5, color: const Color(0xFFB0C4DE), size: 16, unlocked: true),
      SolarPiece(id: 2, name: 'Venus', emoji: '🪐', achievement: 'First Interview 🎯', orbitRadius: 70, angle: 1.2, color: const Color(0xFFE6CCB2), size: 22, unlocked: true),
      SolarPiece(id: 3, name: 'Earth', emoji: '🌍', achievement: 'Skill Swap 🔄', orbitRadius: 100, angle: 2.5, color: const Color(0xFF457B9D), size: 24, unlocked: true),
      SolarPiece(id: 4, name: 'Mars', emoji: '🔴', achievement: 'Roadmap Done 🗺️', orbitRadius: 130, angle: 3.8, color: const Color(0xFFE76F51), size: 20, unlocked: false),
      SolarPiece(id: 5, name: 'Jupiter', emoji: '🟠', achievement: '10 Flashcards 🃏', orbitRadius: 170, angle: 1.8, color: const Color(0xFFF4A261), size: 36, unlocked: false),
      SolarPiece(id: 6, name: 'Saturn', emoji: '🪐', achievement: 'Mock Ace 🤖', orbitRadius: 215, angle: 4.5, color: const Color(0xFFD4A373), size: 40, unlocked: false),
      SolarPiece(id: 7, name: 'Uranus', emoji: '🧊', achievement: 'Resume Built 📄', orbitRadius: 260, angle: 0.8, color: const Color(0xFFA8DADC), size: 28, unlocked: false),
      SolarPiece(id: 8, name: 'Neptune', emoji: '🌊', achievement: 'Streak 7 🔥', orbitRadius: 300, angle: 2.1, color: const Color(0xFF1D3557), size: 28, unlocked: false),
    ];
    // Pre-place Sun and Mercury
    _placedIds.addAll([0, 1]);
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final postsCount = prefs.getInt('community_posts_count') ?? 0;
    if (postsCount > 0) {
      setState(() {
        _allPieces[4].unlocked = true; // Mars unlocks after first post
      });
    }
  }

  List<SolarPiece> get _unplacedPieces => _allPieces.where((p) => p.unlocked && !_placedIds.contains(p.id)).toList();
  int get _placedCount => _placedIds.length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A), // Dark space background
      appBar: AppBar(
        backgroundColor: Colors.transparent, 
        elevation: 0,
        title: const Text('Solar System Puzzle', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          _buildUserTabs(),
          Expanded(
            child: _viewingUser == 0 ? _buildMySolarSystem() : _buildOtherSolarSystem(),
          ),
          if (_viewingUser == 0) _buildInventory(),
        ],
      ),
    );
  }

  Widget _buildUserTabs() {
    return Container(
      height: 50,
      margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _userTab('You', '👤', 0, null),
          ..._otherUsers.asMap().entries.map((e) => _userTab(e.value['name'] as String, e.value['initial'] as String, e.key + 1, Color(e.value['color'] as int))),
        ],
      ),
    );
  }

  Widget _userTab(String name, String icon, int idx, Color? color) {
    final sel = _viewingUser == idx;
    return GestureDetector(
      onTap: () => setState(() => _viewingUser = idx),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: sel ? (color ?? AppColors.primary) : Colors.white12,
          borderRadius: BorderRadius.circular(14),
          border: sel ? null : Border.all(color: Colors.white24),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(icon, style: TextStyle(fontSize: 14, color: sel ? Colors.white : Colors.white70)),
          const SizedBox(width: 6),
          Text(name, style: TextStyle(color: sel ? Colors.white : Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }

  Widget _buildMySolarSystem() {
    return InteractiveViewer(
      minScale: 0.5,
      maxScale: 2.0,
      boundaryMargin: const EdgeInsets.all(300),
      child: Center(
        child: SizedBox(
          width: 700,
          height: 700,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Orbits
              for (final p in _allPieces)
                if (p.orbitRadius > 0)
                  Container(
                    width: p.orbitRadius * 2,
                    height: p.orbitRadius * 2,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white12, width: 1.5, style: BorderStyle.solid),
                    ),
                  ),
              
              // Target slots and placed planets
              for (final p in _allPieces)
                Positioned(
                  left: 350 - p.size / 2 + p.orbitRadius * cos(p.angle) - (_placedIds.contains(p.id) ? 0 : 20),
                  top: 350 - p.size / 2 + p.orbitRadius * sin(p.angle) - (_placedIds.contains(p.id) ? 0 : 20),
                  child: _placedIds.contains(p.id) ? _placedPlanet(p) : _emptyOrbitSlot(p),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOtherSolarSystem() {
    final user = _otherUsers[_viewingUser - 1];
    final placed = user['placed'] as int;
    return InteractiveViewer(
      minScale: 0.5, maxScale: 2.0, boundaryMargin: const EdgeInsets.all(300),
      child: Center(
        child: SizedBox(
          width: 700, height: 700,
          child: Stack(
            alignment: Alignment.center,
            children: [
              for (final p in _allPieces)
                if (p.orbitRadius > 0)
                  Container(width: p.orbitRadius * 2, height: p.orbitRadius * 2, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white12, width: 1))),
              for (final p in _allPieces)
                Positioned(
                  left: 350 - p.size / 2 + p.orbitRadius * cos(p.angle),
                  top: 350 - p.size / 2 + p.orbitRadius * sin(p.angle),
                  child: p.id < placed ? _placedPlanet(p) : Container(width: p.size, height: p.size, decoration: BoxDecoration(color: Colors.white12, shape: BoxShape.circle)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyOrbitSlot(SolarPiece p) {
    return DragTarget<int>(
      onWillAcceptWithDetails: (details) => details.data == p.id, // Only correct planet fits!
      onAcceptWithDetails: (details) {
        setState(() => _placedIds.add(details.data));
        _showSuccessDialog(p);
      },
      builder: (_, candidateData, __) {
        final hovering = candidateData.isNotEmpty;
        return Container(
          width: p.size + 40, height: p.size + 40,
          color: Colors.transparent, // Invisible padding to increase hitbox
          alignment: Alignment.center,
          child: Container(
            width: p.size, height: p.size,
            decoration: BoxDecoration(
              color: hovering ? p.color.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.05),
              shape: BoxShape.circle,
              border: Border.all(color: hovering ? p.color : Colors.white30, width: hovering ? 2 : 1, style: BorderStyle.solid),
            ),
            child: hovering ? const Icon(LucideIcons.check, size: 12, color: Colors.white) : const SizedBox.shrink(),
          ),
        );
      },
    );
  }

  Widget _placedPlanet(SolarPiece p) {
    return GestureDetector(
      onTap: () => _showPlanetDetail(p),
      child: Container(
        width: p.size, height: p.size,
        decoration: BoxDecoration(
          color: p.color,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: p.color.withValues(alpha: 0.6), blurRadius: 12)],
        ),
        child: Center(child: Text(p.emoji, style: TextStyle(fontSize: p.size * 0.6))),
      ),
    );
  }

  Widget _buildInventory() {
    final unplaced = _unplacedPieces;
    final locked = _allPieces.where((p) => !p.unlocked).toList();

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
      decoration: const BoxDecoration(
        color: Color(0xFF1B263B), // Dark panel
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Unlocked Planets', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              Text('${_placedIds.length}/9 Placed', style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 4),
          const Text('Drag these planets to their correct orbit!', style: TextStyle(color: Colors.white60, fontSize: 12)),
          const SizedBox(height: 16),
          if (unplaced.isEmpty)
            const Center(child: Padding(padding: EdgeInsets.all(10), child: Text('All unlocked planets placed! Complete more achievements.', style: TextStyle(color: Colors.white54))))
          else
            SizedBox(
              height: 80,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: unplaced.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (_, i) {
                  final p = unplaced[i];
                  return GestureDetector(
                    onTap: () {
                      setState(() => _placedIds.add(p.id));
                      _showSuccessDialog(p);
                    },
                    child: _inventoryItem(p),
                  );
                },
              ),
            ),
          const SizedBox(height: 20),
          const Text('Locked', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: locked.map((p) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(10)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(LucideIcons.lock, size: 12, color: Colors.white54),
                const SizedBox(width: 6),
                Text(p.achievement, style: const TextStyle(color: Colors.white54, fontSize: 11)),
              ]),
            )).toList(),
          ),
        ],
      ),
    );
  }

  Widget _inventoryItem(SolarPiece p) {
    return Column(
      children: [
        Container(
          width: 50, height: 50,
          decoration: BoxDecoration(color: p.color.withValues(alpha: 0.2), shape: BoxShape.circle, border: Border.all(color: p.color)),
          child: Center(child: Text(p.emoji, style: const TextStyle(fontSize: 24))),
        ),
        const SizedBox(height: 6),
        Text(p.name, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
      ],
    );
  }

  void _showSuccessDialog(SolarPiece p) {
    showDialog(context: context, builder: (_) => Dialog(
      backgroundColor: const Color(0xFF1B263B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('🌟', style: TextStyle(fontSize: 50)),
        const SizedBox(height: 16),
        Text('${p.name} Restored!', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        Text('You placed ${p.name} correctly in its orbit.', style: const TextStyle(color: Colors.white70, fontSize: 14), textAlign: TextAlign.center),
        const SizedBox(height: 20),
        SizedBox(width: double.infinity, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white), onPressed: () => Navigator.pop(context), child: const Text('Awesome'))),
      ])),
    ));
  }

  void _showPlanetDetail(SolarPiece p) {
    showDialog(context: context, builder: (_) => Dialog(
      backgroundColor: const Color(0xFF1B263B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 80, height: 80, decoration: BoxDecoration(color: p.color, shape: BoxShape.circle, boxShadow: [BoxShadow(color: p.color.withValues(alpha: 0.6), blurRadius: 20)]), child: Center(child: Text(p.emoji, style: const TextStyle(fontSize: 40)))),
        const SizedBox(height: 16),
        Text(p.name, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10)), child: Text('Unlocked via: ${p.achievement}', style: const TextStyle(color: AppColors.accent, fontSize: 12, fontWeight: FontWeight.bold))),
        const SizedBox(height: 20),
        SizedBox(width: double.infinity, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white), onPressed: () => Navigator.pop(context), child: const Text('Close'))),
      ])),
    ));
  }
}
