import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:hustlr/core/theme/app_colors.dart';
import 'package:hustlr/features/ai_interview/data/interview_models.dart';
import 'package:hustlr/features/ai_interview/data/interview_service.dart';
import 'package:hustlr/features/ai_interview/presentation/pages/interview_setup_page.dart';

class InterviewResultsPage extends StatefulWidget {
  final String sessionId;
  final String? applicationId;
  final int? scoreThreshold;
  const InterviewResultsPage({
    super.key,
    required this.sessionId,
    this.applicationId,
    this.scoreThreshold,
  });

  @override
  State<InterviewResultsPage> createState() => _InterviewResultsPageState();
}

class _InterviewResultsPageState extends State<InterviewResultsPage> with TickerProviderStateMixin {
  final FlutterTts _tts = FlutterTts();
  InterviewResult? _result;
  bool _loading = true;
  int _pollCount = 0;
  Timer? _pollTimer;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnim;
  late AnimationController _scoreController;
  late Animation<double> _scoreAnim;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _scoreController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
    _scoreAnim = CurvedAnimation(parent: _scoreController, curve: Curves.easeOutCubic);
    _startPolling();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _tts.stop();
    _fadeController.dispose();
    _scoreController.dispose();
    super.dispose();
  }

  void _startPolling() {
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      if (_pollCount >= 30) {
        _pollTimer?.cancel();
        if (mounted) setState(() => _loading = false);
        return;
      }
      try {
        final data = await InterviewService.getResult(widget.sessionId);
        if (mounted) {
          setState(() { _result = data; _pollCount++; });
          if (data.processingComplete) {
            _pollTimer?.cancel();
            setState(() => _loading = false);
            _fadeController.forward();
            Future.delayed(const Duration(milliseconds: 300), () => _scoreController.forward());
            _speakFeedback(data);
          }
        }
      } catch (e) {
        debugPrint('[POLL] Error: $e');
        _pollCount++;
      }
    });
  }

  Future<void> _speakFeedback(InterviewResult data) async {
    try {
      await _tts.setLanguage('en-US');
      await _tts.setSpeechRate(0.5);
      
      String text = "Interview processing complete. You scored ${data.compositeScore}. ";
      if (data.upskillingAreas != null && data.upskillingAreas!.isNotEmpty) {
        text += "To improve, you should focus on: ${data.upskillingAreas!.join(', ')}.";
      } else {
        text += "Great job!";
      }
      await _tts.speak(text);
    } catch (e) {
      debugPrint('[TTS] Error: $e');
    }
  }

  Color _tierColor(String? tier) {
    switch (tier) {
      case 'EXCELLENT': return const Color(0xFF22C55E);
      case 'GOOD': return const Color(0xFF3B82F6);
      case 'NEEDS_IMPROVEMENT': return const Color(0xFFF59E0B);
      case 'POOR': return const Color(0xFFEF4444);
      default: return Colors.white54;
    }
  }

  Color _scoreColor(double? s) {
    if (s == null) return Colors.white54;
    if (s >= 7) return const Color(0xFF22C55E);
    if (s >= 4) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return _buildLoading();
    return _buildResults();
  }

  // ── LOADING ──────────────────────────────────────────────────
  Widget _buildLoading() {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(width: 48, height: 48, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white)),
          const SizedBox(height: 24),
          const Text('PROCESSING INTERVIEW', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 2)),
          const SizedBox(height: 8),
          Text('AI is scoring your responses...\nThis may take a minute.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12, height: 1.6)),
          const SizedBox(height: 32),
          ...[
            _step(LucideIcons.mic, 'Transcribing audio', _pollCount > 2),
            _step(LucideIcons.barChart2, 'Scoring responses', _pollCount > 5),
            _step(LucideIcons.shield, 'Generating feedback', _pollCount > 8),
            _step(LucideIcons.award, 'Performance classification', _pollCount > 10),
          ],
        ]),
      ),
    );
  }

  Widget _step(IconData icon, String text, bool done) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(done ? LucideIcons.checkCircle : icon, size: 16, color: done ? const Color(0xFF22C55E) : Colors.white38),
        const SizedBox(width: 10),
        Text(text.toUpperCase(), style: TextStyle(color: done ? const Color(0xFF22C55E) : Colors.white38, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1)),
      ]),
    );
  }

  // ── RESULTS ───────────────────────────────────────────────────
  Widget _buildResults() {
    final r = _result;
    final score = r?.compositeScore;
    final tier = r?.performanceTier;
    final tierColor = _tierColor(tier);
    final isScreening = widget.applicationId != null;
    final threshold = widget.scoreThreshold ?? 60;
    final passed = isScreening && score != null && score >= threshold;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: CustomScrollView(slivers: [

            // ── Header
            SliverToBoxAdapter(child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Text(isScreening ? 'SCREENING RESULTS' : 'INTERVIEW COMPLETE',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 2)),
            )),

            // ── Company Screening Verdict
            if (isScreening) SliverToBoxAdapter(child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: passed
                    ? [const Color(0xFF22C55E).withValues(alpha: 0.15), const Color(0xFF16A34A).withValues(alpha: 0.08)]
                    : [const Color(0xFFEF4444).withValues(alpha: 0.15), const Color(0xFFDC2626).withValues(alpha: 0.08)]),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: passed ? const Color(0xFF22C55E).withValues(alpha: 0.4) : const Color(0xFFEF4444).withValues(alpha: 0.4)),
                ),
                child: Column(children: [
                  Icon(passed ? LucideIcons.checkCircle : LucideIcons.xCircle, color: passed ? const Color(0xFF22C55E) : const Color(0xFFEF4444), size: 36),
                  const SizedBox(height: 10),
                  Text(passed ? '🎉 You Passed the Screening!' : 'Screening Not Passed',
                    style: TextStyle(color: passed ? const Color(0xFF22C55E) : const Color(0xFFEF4444), fontSize: 18, fontWeight: FontWeight.w900),
                    textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  Text(passed
                    ? 'Great job! The company will review your profile and reach out to schedule a human interview.'
                    : 'Your score of ${score?.toStringAsFixed(0) ?? "—"} was below the required threshold of $threshold. Keep practising!',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 13, height: 1.5),
                    textAlign: TextAlign.center),
                ]),
              ),
            )),

            // ── Animated Score Ring
            if (score != null) SliverToBoxAdapter(child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: AnimatedBuilder(
                animation: _scoreAnim,
                builder: (_, __) => Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  child: Column(children: [
                    Stack(alignment: Alignment.center, children: [
                      SizedBox(
                        width: 120, height: 120,
                        child: CustomPaint(painter: _ScoreRingPainter(
                          progress: _scoreAnim.value * score / 100,
                          color: tierColor,
                        )),
                      ),
                      Column(mainAxisSize: MainAxisSize.min, children: [
                        Text(
                          (_scoreAnim.value * score).toStringAsFixed(0),
                          style: TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: tierColor),
                        ),
                        Text('/100', style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.3))),
                      ]),
                    ]),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(color: tierColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
                      child: Text(tier?.replaceAll('_', ' ') ?? '—',
                        style: TextStyle(color: tierColor, fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 1)),
                    ),
                    if (r?.tierRationale != null) ...[
                      const SizedBox(height: 12),
                      Text(r!.tierRationale!, textAlign: TextAlign.center, style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12, height: 1.5)),
                    ],
                  ]),
                ),
              ),
            )),

            // ── Per-Metric Average Bars
            if (r?.perQuestionScores != null && r!.perQuestionScores!.isNotEmpty)
              SliverToBoxAdapter(child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.04), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withValues(alpha: 0.08))),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('SKILL BREAKDOWN', style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
                    const SizedBox(height: 14),
                    ..._buildMetricBars(r!.perQuestionScores!),
                  ]),
                ),
              )),

            // ── Strong Areas
            if (r?.strongAreas != null && r!.strongAreas!.isNotEmpty)
              SliverToBoxAdapter(child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: _areaSection('💪 STRONG AREAS', r!.strongAreas!, const Color(0xFF22C55E)),
              )),

            // ── Improvement Roadmap
            if (r?.upskillingAreas != null && r!.upskillingAreas!.isNotEmpty)
              SliverToBoxAdapter(child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: _improvementRoadmap(r!.upskillingAreas!),
              )),

            // ── Q&A Breakdown Label
            if (r?.perQuestionScores != null && r!.perQuestionScores!.isNotEmpty)
              SliverToBoxAdapter(child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                child: Text('QUESTION BREAKDOWN', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white.withValues(alpha: 0.4), letterSpacing: 2)),
              )),

            // ── Q&A Cards
            if (r?.perQuestionScores != null)
              SliverList(delegate: SliverChildBuilderDelegate(
                (context, idx) => Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: _buildQACard(r!.perQuestionScores![idx], idx),
                ),
                childCount: r!.perQuestionScores!.length,
              )),

            // ── Actions
            SliverToBoxAdapter(child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
              child: GestureDetector(
                onTap: () => Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const InterviewSetupPage()), (r) => r.isFirst),
                child: Container(
                  height: 54,
                  decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(14)),
                  child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(LucideIcons.rotateCcw, color: Colors.white, size: 18),
                    SizedBox(width: 10),
                    Text('PRACTICE AGAIN', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 1)),
                  ]),
                ),
              ),
            )),
            SliverToBoxAdapter(child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
              child: GestureDetector(
                onTap: () => Navigator.of(context).popUntil((r) => r.isFirst),
                child: Container(height: 46, alignment: Alignment.center, child: Text('BACK TO DASHBOARD', style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1, decoration: TextDecoration.underline, decorationColor: Colors.white.withValues(alpha: 0.4)))),
              ),
            )),
          ]),
        ),
      ),
    );
  }

  List<Widget> _buildMetricBars(List<QuestionScore> scores) {
    double avg(double? Function(QuestionScore) f) {
      final vals = scores.map(f).whereType<double>().toList();
      return vals.isEmpty ? 0 : vals.reduce((a, b) => a + b) / vals.length;
    }
    final metrics = [
      ('Relevance', avg((q) => q.relevance), const Color(0xFF3B82F6)),
      ('Clarity', avg((q) => q.clarity), const Color(0xFF22C55E)),
      ('Confidence', avg((q) => q.confidence), const Color(0xFFF59E0B)),
      ('Completeness', avg((q) => q.completeness), AppColors.primary),
    ];
    return metrics.map((m) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(m.$1, style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12, fontWeight: FontWeight.w600)),
          const Spacer(),
          Text('${m.$2.toStringAsFixed(1)}/10', style: TextStyle(color: m.$3, fontSize: 12, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 5),
        AnimatedBuilder(
          animation: _scoreAnim,
          builder: (_, __) => ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (_scoreAnim.value * m.$2 / 10).clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: Colors.white.withValues(alpha: 0.06),
              valueColor: AlwaysStoppedAnimation(m.$3),
            ),
          ),
        ),
      ]),
    )).toList();
  }

  Widget _areaSection(String title, List<String> areas, Color color) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: TextStyle(fontSize: 11, color: color.withValues(alpha: 0.8), fontWeight: FontWeight.w700, letterSpacing: 1)),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8, children: areas.map((a) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withValues(alpha: 0.25))),
        child: Text(a, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
      )).toList()),
    ]);
  }

  Widget _improvementRoadmap(List<String> areas) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF59E0B).withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.2)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(LucideIcons.trendingUp, color: Color(0xFFF59E0B), size: 16),
          SizedBox(width: 8),
          Text('YOUR IMPROVEMENT ROADMAP', style: TextStyle(color: Color(0xFFF59E0B), fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1)),
        ]),
        const SizedBox(height: 12),
        ...areas.asMap().entries.map((e) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 22, height: 22,
              decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFF59E0B)),
              child: Center(child: Text('${e.key + 1}', style: const TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.w900))),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(e.value, style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 13, height: 1.5))),
          ]),
        )),
      ]),
    );
  }

  Widget _buildQACard(QuestionScore qa, int idx) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          title: Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4)),
              child: Text('Q${idx + 1}', style: const TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.w900)),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(qa.questionText, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600), maxLines: 2, overflow: TextOverflow.ellipsis)),
          ]),
          children: [
            // Mini metric row
            Row(children: [
              if (qa.relevance != null) _miniScore('REL', qa.relevance!),
              if (qa.clarity != null) ...[const SizedBox(width: 6), _miniScore('CLR', qa.clarity!)],
              if (qa.confidence != null) ...[const SizedBox(width: 6), _miniScore('CNF', qa.confidence!)],
              if (qa.completeness != null) ...[const SizedBox(width: 6), _miniScore('CMP', qa.completeness!)],
            ]),
            // Transcript
            if (qa.transcript != null && qa.transcript!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text('YOUR ANSWER:', style: TextStyle(fontSize: 9, color: Colors.white.withValues(alpha: 0.3), fontWeight: FontWeight.w700, letterSpacing: 1)),
              const SizedBox(height: 4),
              Text('"${qa.transcript}"', style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.5), fontStyle: FontStyle.italic, height: 1.5)),
            ],
            // Explanation / Feedback
            if (qa.explanation != null && qa.explanation!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.primary.withValues(alpha: 0.2))),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Icon(LucideIcons.sparkles, size: 13, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(child: Text(qa.explanation!, style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.6), height: 1.5))),
                ]),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _miniScore(String label, double value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(4), border: Border.all(color: _scoreColor(value).withValues(alpha: 0.3))),
      child: Text('$label ${value.toStringAsFixed(0)}', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: _scoreColor(value), letterSpacing: 0.5)),
    );
  }
}

// ── Animated Score Ring Painter ──────────────────────────────
class _ScoreRingPainter extends CustomPainter {
  final double progress;
  final Color color;
  _ScoreRingPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 8;
    const startAngle = -math.pi / 2;
    final sweepAngle = 2 * math.pi * progress;

    // Background ring
    canvas.drawCircle(center, radius, Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round);

    // Colored progress arc
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle, sweepAngle, false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_ScoreRingPainter old) => old.progress != progress || old.color != color;
}

