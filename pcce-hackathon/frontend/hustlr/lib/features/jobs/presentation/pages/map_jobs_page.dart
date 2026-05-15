import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:hustlr/core/theme/app_colors.dart';
import 'dart:math';

import 'package:hustlr/features/jobs/domain/models/job_listing_model.dart';
import 'package:hustlr/features/jobs/presentation/pages/job_detail_page.dart';

class MapJobsPage extends StatefulWidget {
  final List<JobListingModel> jobs;
  const MapJobsPage({super.key, this.jobs = const []});
  @override
  State<MapJobsPage> createState() => _MapJobsPageState();
}

class _MapJobsPageState extends State<MapJobsPage> with TickerProviderStateMixin {
  double _radius = 10;
  int _selectedPin = -1;
  bool _showFilters = false;
  bool _companyMode = false;
  final _selectedRoles = <String>{'All'};
  double _salaryMin = 5, _salaryMax = 50;
  int _workMode = 0; // 0=all, 1=remote, 2=hybrid, 3=onsite
  int _expLevel = 0; // 0=all, 1=fresher, 2=1-3yr, 3=3-5yr, 4=5+
  late AnimationController _pulseCtrl;

  late final List<Map<String, dynamic>> _jobs;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();

    final rng = Random();
    if (widget.jobs.isEmpty) {
      _jobs = const [
        {'role': 'Flutter Dev', 'company': 'Razorpay', 'salary': '₹18–24 LPA', 'dist': '1.2 km', 'commuteCar': '8 min', 'commuteTransit': '18 min', 'x': 0.55, 'y': 0.35, 'type': 'Onsite', 'exp': '1-3 yr', 'match': 95, 'stack': 'Flutter, Dart, Firebase', 'job_obj': null},
        {'role': 'SDE-1', 'company': 'Meesho', 'salary': '₹12–18 LPA', 'dist': '3.7 km', 'commuteCar': '15 min', 'commuteTransit': '28 min', 'x': 0.3, 'y': 0.5, 'type': 'Hybrid', 'exp': 'Fresher', 'match': 87, 'stack': 'React, Node.js', 'job_obj': null},
        {'role': 'Frontend Dev', 'company': 'CRED', 'salary': '₹20–28 LPA', 'dist': '5.1 km', 'commuteCar': '22 min', 'commuteTransit': '35 min', 'x': 0.72, 'y': 0.6, 'type': 'Onsite', 'exp': '3-5 yr', 'match': 79, 'stack': 'React, TypeScript', 'job_obj': null},
      ];
    } else {
      _jobs = widget.jobs.map((j) {
        return {
          'role': j.title,
          'company': j.company,
          'salary': j.salaryRange ?? 'Competitive',
          'dist': '${(1.0 + rng.nextDouble() * 9.0).toStringAsFixed(1)} km',
          'commuteCar': '${(10 + rng.nextInt(30))} min',
          'commuteTransit': '${(20 + rng.nextInt(40))} min',
          'x': 0.1 + rng.nextDouble() * 0.8,
          'y': 0.1 + rng.nextDouble() * 0.8,
          'type': j.location.toLowerCase().contains('remote') ? 'Remote' : 'Onsite',
          'exp': j.experienceRequired ?? '1-3 yr',
          'match': (j.matchScore * 100).toInt(),
          'stack': j.skillsRequired.take(3).join(', '),
          'job_obj': j,
        };
      }).toList();
    }
  }

  List<Map<String, dynamic>> get _filteredJobs {
    return _jobs.where((j) {
      final distStr = j['dist'] as String;
      final dist = double.tryParse(distStr.replaceAll(' km', '')) ?? 0.0;
      if (dist > _radius) return false;
      return true;
    }).toList();
  }

  @override
  void dispose() { _pulseCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final filtered = _filteredJobs;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Map Jobs'),
        actions: [
          GestureDetector(
            onTap: () => setState(() => _companyMode = !_companyMode),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: _companyMode ? AppColors.accentPurple.withValues(alpha: 0.15) : AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(_companyMode ? LucideIcons.building2 : LucideIcons.mapPin, size: 14, color: _companyMode ? AppColors.accentPurple : AppColors.primary),
                const SizedBox(width: 4),
                Text(_companyMode ? 'HQ Mode' : 'Jobs', style: TextStyle(color: _companyMode ? AppColors.accentPurple : AppColors.primary, fontSize: 11, fontWeight: FontWeight.bold)),
              ]),
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _showFilters = !_showFilters),
            child: Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
              child: const Icon(LucideIcons.sliders, size: 16, color: AppColors.primary),
            ),
          ),
        ],
      ),
      body: Stack(children: [
        // Map canvas
        CustomPaint(
          size: Size.infinite,
          painter: _MapPainter(isDark: isDark, radius: _radius, jobs: filtered, selectedPin: _selectedPin, companyMode: _companyMode, pulseValue: _pulseCtrl),
        ),

        // Job pins
        ...filtered.asMap().entries.map((e) {
          final i = e.key;
          final j = e.value;
          return Positioned(
            left: MediaQuery.of(context).size.width * (j['x'] as double) - 18,
            top: (MediaQuery.of(context).size.height * 0.6) * (j['y'] as double) + 60,
            child: GestureDetector(
              onTap: () => setState(() => _selectedPin = _selectedPin == i ? -1 : i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: EdgeInsets.all(_selectedPin == -1 ? 6 : 4),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: _selectedPin == i ? 42 : 36,
                    height: _selectedPin == i ? 42 : 36,
                    decoration: BoxDecoration(
                      color: _selectedPin == i ? AppColors.primary : (_companyMode ? AppColors.accentPurple : _pinColor(j)),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2.5),
                      boxShadow: [BoxShadow(color: (_selectedPin == i ? AppColors.primary : Colors.black).withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 3))],
                    ),
                    child: Icon(_companyMode ? LucideIcons.building2 : LucideIcons.briefcase, color: Colors.white, size: _selectedPin == i ? 18 : 14),
                  ),
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: (isDark ? AppColors.surfaceDark : Colors.white).withValues(alpha: 0.95), borderRadius: BorderRadius.circular(4),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4)]),
                    child: Text(_companyMode ? j['company'] as String : j['role'] as String, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
                  ),
                ]),
              ),
            ),
          );
        }),

        // User location pulse
        Positioned(
          left: MediaQuery.of(context).size.width * 0.48 - 12,
          top: (MediaQuery.of(context).size.height * 0.6) * 0.45 + 55,
          child: AnimatedBuilder(
            animation: _pulseCtrl,
            builder: (_, __) => Container(
              width: 24 + (_pulseCtrl.value * 16),
              height: 24 + (_pulseCtrl.value * 16),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.info.withValues(alpha: 0.15 * (1 - _pulseCtrl.value)),
              ),
              child: Center(child: Container(
                width: 16, height: 16,
                decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.info, border: Border.all(color: Colors.white, width: 2.5)),
              )),
            ),
          ),
        ),

        // Filter chips top
        Positioned(
          top: 8, left: 12, right: 12,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              _topChip('${_radius.toInt()} km', true, isDark),
              const SizedBox(width: 8),
              _topChip('${filtered.length} jobs', false, isDark),
              const SizedBox(width: 8),
              _topChip(_workMode == 0 ? 'All Modes' : ['', 'Remote', 'Hybrid', 'Onsite'][_workMode], false, isDark),
            ]),
          ),
        ),

        // Filters panel
        if (_showFilters) _filterPanel(isDark),

        // Bottom sheet
        Positioned(
          bottom: 0, left: 0, right: 0,
          child: _selectedPin >= 0 ? _jobDetailCard(filtered[_selectedPin], isDark) : _bottomSummary(filtered, isDark),
        ),

        // Radius slider
        if (_selectedPin < 0) Positioned(
          bottom: _selectedPin >= 0 ? 220 : 160, left: 20, right: 20,
          child: _radiusSlider(isDark),
        ),
      ]),
    );
  }

  Widget _radiusSlider(bool isDark) {
    final labels = {5.0: '5 km', 10.0: '10 km', 25.0: '25 km', 50.0: '50 km', 100.0: '100 km'};
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: (isDark ? AppColors.surfaceDark : Colors.white).withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 12)],
      ),
      child: Row(children: [
        const Icon(LucideIcons.radar, size: 16, color: AppColors.primary),
        Expanded(child: Slider(
          value: _radius, min: 5, max: 100, divisions: 4,
          activeColor: AppColors.primary,
          label: labels[_radius] ?? '${_radius.toInt()} km',
          onChanged: (v) => setState(() { _radius = v; _selectedPin = -1; }),
        )),
        Text('${_radius.toInt()} km', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.primary)),
      ]),
    );
  }

  Widget _bottomSummary(List<Map<String, dynamic>> jobs, bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 20, offset: const Offset(0, -5))],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('${jobs.length} Jobs Nearby', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
            child: Text('< ${_radius.toInt()} km', style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        ]),
        const SizedBox(height: 12),
        ...jobs.take(3).map((j) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(color: _pinColor(j), shape: BoxShape.circle)),
            const SizedBox(width: 10),
            Expanded(child: Text('${j['role']} · ${j['company']}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
            Text(j['dist'] as String, style: const TextStyle(color: AppColors.textSecondaryLight, fontSize: 12)),
            const SizedBox(width: 10),
            Text(j['salary'] as String, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12)),
          ]),
        )),
      ]),
    );
  }

  Widget _jobDetailCard(Map<String, dynamic> job, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 24, offset: const Offset(0, -8))],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 14),
        Row(children: [
          Container(width: 48, height: 48, decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
            child: Center(child: Text((job['company'] as String)[0], style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 20)))),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(job['role'] as String, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
            Text(job['company'] as String, style: const TextStyle(color: AppColors.textSecondaryLight, fontSize: 13)),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: Text('${job['match']}% Match', style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ]),
        const SizedBox(height: 14),
        Wrap(spacing: 10, runSpacing: 8, children: [
          _detailChip(LucideIcons.indianRupee, job['salary'] as String),
          _detailChip(LucideIcons.mapPin, job['dist'] as String),
          _detailChip(LucideIcons.briefcase, job['type'] as String),
        ]),
        const SizedBox(height: 12),
        // Commute overlay
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: AppColors.info.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.info.withValues(alpha: 0.12))),
          child: Row(children: [
            const Icon(LucideIcons.clock, size: 14, color: AppColors.info),
            const SizedBox(width: 8),
            Text('🚗 ${job['commuteCar']}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(width: 12),
            Text('🚇 ${job['commuteTransit']}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            const Spacer(),
            Text('from your location', style: TextStyle(color: AppColors.textSecondaryLight, fontSize: 10)),
          ]),
        ),
        const SizedBox(height: 10),
        // Tech stack
        Wrap(spacing: 6, children: (job['stack'] as String).split(', ').map((t) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(6)),
          child: Text(t, style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w600)),
        )).toList()),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: GestureDetector(
            onTap: () {
              if (job['job_obj'] != null) {
                Navigator.push(context, MaterialPageRoute(builder: (_) => JobDetailPage(job: (job['job_obj'] as JobListingModel).toJson())));
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(12)),
              child: const Center(child: Text('Quick Apply', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14))),
            ),
          )),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)), borderRadius: BorderRadius.circular(12)),
            child: const Icon(LucideIcons.bookmark, color: AppColors.primary, size: 18),
          ),
        ]),
      ]),
    );
  }

  Widget _filterPanel(bool isDark) {
    return Positioned(
      top: 50, left: 16, right: 16,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: (isDark ? AppColors.surfaceDark : Colors.white).withValues(alpha: 0.97),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 20)],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Filters', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            GestureDetector(onTap: () => setState(() => _showFilters = false), child: const Icon(LucideIcons.x, size: 20)),
          ]),
          const SizedBox(height: 14),
          const Text('Work Mode', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 8),
          Row(children: [
            _filterToggle(0, 'All', _workMode == 0, () => setState(() => _workMode = 0), isDark),
            const SizedBox(width: 6),
            _filterToggle(1, 'Remote', _workMode == 1, () => setState(() => _workMode = 1), isDark),
            const SizedBox(width: 6),
            _filterToggle(2, 'Hybrid', _workMode == 2, () => setState(() => _workMode = 2), isDark),
            const SizedBox(width: 6),
            _filterToggle(3, 'Onsite', _workMode == 3, () => setState(() => _workMode = 3), isDark),
          ]),
          const SizedBox(height: 14),
          const Text('Experience', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 6, children: [
            _filterToggle(0, 'All', _expLevel == 0, () => setState(() => _expLevel = 0), isDark),
            _filterToggle(1, 'Fresher', _expLevel == 1, () => setState(() => _expLevel = 1), isDark),
            _filterToggle(2, '1-3 yr', _expLevel == 2, () => setState(() => _expLevel = 2), isDark),
            _filterToggle(3, '3-5 yr', _expLevel == 3, () => setState(() => _expLevel = 3), isDark),
            _filterToggle(4, '5+ yr', _expLevel == 4, () => setState(() => _expLevel = 4), isDark),
          ]),
          const SizedBox(height: 14),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Salary Range', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            Text('₹${_salaryMin.toInt()}–${_salaryMax.toInt()} LPA', style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.bold)),
          ]),
          RangeSlider(values: RangeValues(_salaryMin, _salaryMax), min: 3, max: 60, divisions: 19, activeColor: AppColors.primary,
            onChanged: (v) => setState(() { _salaryMin = v.start; _salaryMax = v.end; })),
        ]),
      ),
    );
  }

  Widget _filterToggle(int idx, String label, bool sel, VoidCallback onTap, bool isDark) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: sel ? AppColors.primary : (isDark ? AppColors.surfaceDark2 : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(label, style: TextStyle(color: sel ? Colors.white : AppColors.textSecondaryLight, fontSize: 12, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _topChip(String label, bool sel, bool isDark) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
    decoration: BoxDecoration(
      color: sel ? AppColors.primary : (isDark ? AppColors.surfaceDark : Colors.white).withValues(alpha: 0.95),
      borderRadius: BorderRadius.circular(20),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 6, offset: const Offset(0, 2))],
    ),
    child: Text(label, style: TextStyle(color: sel ? Colors.white : (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight), fontWeight: FontWeight.w600, fontSize: 13)),
  );

  Widget _detailChip(IconData icon, String text) => Row(mainAxisSize: MainAxisSize.min, children: [
    Icon(icon, size: 13, color: AppColors.textSecondaryLight),
    const SizedBox(width: 4),
    Text(text, style: const TextStyle(color: AppColors.textSecondaryLight, fontSize: 12, fontWeight: FontWeight.w500)),
  ]);

  Color _pinColor(Map<String, dynamic> j) {
    final match = j['match'] as int;
    return match >= 90 ? AppColors.success : match >= 75 ? AppColors.warning : AppColors.accentOrange;
  }
}

// ── Custom Map Painter ──────────────────────────────────────────────────────
class _MapPainter extends CustomPainter {
  final bool isDark;
  final double radius;
  final List<Map<String, dynamic>> jobs;
  final int selectedPin;
  final bool companyMode;
  final Animation<double> pulseValue;

  _MapPainter({required this.isDark, required this.radius, required this.jobs, required this.selectedPin, required this.companyMode, required this.pulseValue}) : super(repaint: pulseValue);

  @override
  void paint(Canvas canvas, Size size) {
    // Background
    final bg = isDark ? const Color(0xFF131E30) : const Color(0xFFE8EEF7);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = bg);

    // Grid roads
    final roadColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFD5DFE9);
    final roadPaint = Paint()..color = roadColor..strokeWidth = 1.2;
    for (var x = 0.0; x < size.width; x += 45) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), roadPaint);
    }
    for (var y = 0.0; y < size.height; y += 45) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), roadPaint);
    }

    // Major roads
    final majorPaint = Paint()..color = (isDark ? const Color(0xFF273549) : const Color(0xFFC2CEDE))..strokeWidth = 2.5;
    canvas.drawLine(Offset(0, size.height * 0.4), Offset(size.width, size.height * 0.35), majorPaint);
    canvas.drawLine(Offset(size.width * 0.3, 0), Offset(size.width * 0.35, size.height), majorPaint);
    canvas.drawLine(Offset(size.width * 0.7, 0), Offset(size.width * 0.65, size.height), majorPaint);

    // Blocks (buildings)
    final blockPaint = Paint()..color = isDark ? const Color(0xFF1A2840) : const Color(0xFFDAE3ED);
    final rng = Random(42);
    for (var i = 0; i < 30; i++) {
      final bx = rng.nextDouble() * size.width;
      final by = rng.nextDouble() * size.height;
      final bw = 15.0 + rng.nextDouble() * 25;
      final bh = 15.0 + rng.nextDouble() * 25;
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(bx, by, bw, bh), const Radius.circular(3)), blockPaint);
    }

    // User location radius circle
    final center = Offset(size.width * 0.48, size.height * 0.45);
    final radiusPx = (radius / 100) * size.width * 0.9;
    canvas.drawCircle(center, radiusPx, Paint()..color = const Color(0xFF3B82F6).withValues(alpha: 0.08)..style = PaintingStyle.fill);
    canvas.drawCircle(center, radiusPx, Paint()..color = const Color(0xFF3B82F6).withValues(alpha: 0.25)..style = PaintingStyle.stroke..strokeWidth = 1.5);
  }

  @override
  bool shouldRepaint(covariant _MapPainter old) => old.radius != radius || old.selectedPin != selectedPin || old.companyMode != companyMode;
}
