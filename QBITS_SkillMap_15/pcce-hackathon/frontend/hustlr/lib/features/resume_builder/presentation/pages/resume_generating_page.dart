/// Resume Builder — Step 5A: Generating (animated progress)
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:hustlr/core/theme/app_colors.dart';
import 'package:hustlr/features/resume_builder/data/resume_models.dart';
import 'package:hustlr/features/resume_builder/data/resume_service.dart';
import 'package:hustlr/features/resume_builder/presentation/pages/resume_preview_page.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class ResumeGeneratingPage extends StatefulWidget {
  final ResumeFlowData flowData;
  const ResumeGeneratingPage({super.key, required this.flowData});
  @override
  State<ResumeGeneratingPage> createState() => _ResumeGeneratingPageState();
}

class _ResumeGeneratingPageState extends State<ResumeGeneratingPage> with TickerProviderStateMixin {
  int _currentStep = 0;
  String _error = '';
  late AnimationController _pulseCtrl;

  final _steps = [
    _GenStep('Fetching GitHub data', LucideIcons.github),
    _GenStep('Analyzing your profile', LucideIcons.brain),
    _GenStep('Generating resume content', LucideIcons.fileText),
    _GenStep('Applying template', LucideIcons.layout),
    _GenStep('Scoring ATS compatibility', LucideIcons.shieldCheck),
  ];

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat(reverse: true);
    _generate();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    try {
      // Simulate step progression while the actual call runs
      final progressTimer = Timer.periodic(const Duration(seconds: 3), (t) {
        if (_currentStep < _steps.length - 1 && mounted) {
          setState(() => _currentStep++);
        }
      });

      final result = await ResumeService.generateResume(
        candidateProfile: widget.flowData.buildCandidateProfile(),
        selectedRepos: widget.flowData.selectedRepos,
        jdText: widget.flowData.jdText,
        extraInfo: widget.flowData.extraInfo,
        templateName: widget.flowData.templateName,
        githubToken: widget.flowData.githubToken.isNotEmpty ? widget.flowData.githubToken : null,
      );

      progressTimer.cancel();
      widget.flowData.result = result;

      // Cache the raw generate result so other pages can reuse it
      try {
        final prefs = await SharedPreferences.getInstance();
        final cached = jsonEncode({
          'resume_json': result.resumeJson,
          'analysis': result.analysis,
          'ats_score': {
            'score': result.atsScore.score,
            'matched_keywords': result.atsScore.matchedKeywords,
            'missing_keywords': result.atsScore.missingKeywords,
            'suggestions': result.atsScore.suggestions,
            'breakdown': result.atsScore.breakdown,
          },
          'template': result.template,
        });
        await prefs.setString('last_generate_result', cached);
      } catch (_) {}

      if (mounted) {
        setState(() => _currentStep = _steps.length); // All done
        await Future.delayed(const Duration(milliseconds: 800));
        Navigator.pushReplacement(context, MaterialPageRoute(
          builder: (_) => ResumePreviewPage(flowData: widget.flowData),
        ));
      }
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // AI Animation
              AnimatedBuilder(
                animation: _pulseCtrl,
                builder: (_, __) => Container(
                  width: 80 + _pulseCtrl.value * 10,
                  height: 80 + _pulseCtrl.value * 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: [
                      AppColors.primaryLight.withValues(alpha: 0.3),
                      AppColors.primaryLight.withValues(alpha: 0.05),
                    ]),
                  ),
                  child: const Icon(LucideIcons.sparkles, color: Colors.white, size: 32),
                ),
              ),
              const SizedBox(height: 32),

              const Text('BUILDING YOUR RESUME', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 2)),
              const SizedBox(height: 8),
              Text('AI is crafting your perfect resume...', style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 13)),

              const SizedBox(height: 40),

              // Steps
              ...List.generate(_steps.length, (i) {
                final step = _steps[i];
                final done = i < _currentStep;
                final active = i == _currentStep;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Row(children: [
                    Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: done ? Colors.green.withValues(alpha: 0.15) : active ? AppColors.primaryLight.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.04),
                      ),
                      child: done
                        ? const Icon(Icons.check_rounded, color: Colors.green, size: 18)
                        : active
                          ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryLight))
                          : Icon(step.icon, color: Colors.white.withValues(alpha: 0.2), size: 16),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      step.label,
                      style: TextStyle(
                        color: done ? Colors.green : active ? Colors.white : Colors.white.withValues(alpha: 0.3),
                        fontSize: 14,
                        fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ]),
                );
              }),

              if (_error.isNotEmpty) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                  ),
                  child: Column(children: [
                    Text('Generation failed', style: const TextStyle(color: Colors.red, fontSize: 14, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(_error, style: TextStyle(color: Colors.red.withValues(alpha: 0.7), fontSize: 11)),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () {
                        setState(() { _error = ''; _currentStep = 0; });
                        _generate();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
                        child: const Text('Retry', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ]),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _GenStep {
  final String label;
  final IconData icon;
  const _GenStep(this.label, this.icon);
}
