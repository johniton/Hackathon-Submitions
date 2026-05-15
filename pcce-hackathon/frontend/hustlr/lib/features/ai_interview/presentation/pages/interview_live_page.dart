import 'dart:async';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hustlr/core/theme/app_colors.dart';
import 'package:hustlr/features/ai_interview/data/interview_models.dart';
import 'package:hustlr/features/ai_interview/data/interview_service.dart';
import 'package:hustlr/features/ai_interview/presentation/pages/interview_results_page.dart';

/// Offline fallback questions
final _offlineQuestions = [
  QuestionItem(order: 2, questionText: 'What tools and technologies do you use most often in your work?'),
  QuestionItem(order: 3, questionText: 'How do you approach debugging a complex issue in production?'),
  QuestionItem(order: 4, questionText: 'Describe a challenging project you worked on and what you learned.'),
  QuestionItem(order: 5, questionText: 'Where do you see yourself in 2-3 years? What skills are you actively developing?'),
];

enum InterviewPhase { init, faceCapture, speaking, recording, analyzing, done }

class InterviewLivePage extends StatefulWidget {
  final InterviewSetup setup;
  final String? applicationId;     // If set, updates job_applications table
  final int? jobScoreThreshold;    // Min score to pass company screening
  const InterviewLivePage({
    super.key,
    required this.setup,
    this.applicationId,
    this.jobScoreThreshold,
  });

  @override
  State<InterviewLivePage> createState() => _InterviewLivePageState();
}

class _InterviewLivePageState extends State<InterviewLivePage> with TickerProviderStateMixin {
  // Camera
  CameraController? _cameraController;
  bool _cameraReady = false;

  // TTS
  late FlutterTts _tts;

  // Interview state
  String? _sessionId;
  final List<QuestionItem> _questions = [];
  int _currentIdx = 0;
  InterviewPhase _phase = InterviewPhase.init;
  int _elapsedSec = 0;
  Timer? _timer;
  bool _isRecording = false;

  // Cheating detection
  String? _baselineImagePath;
  bool _faceMismatchWarning = false;
  int _warningCountdown = 10;
  Timer? _warningTimer;

  // Animations
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;
  late AnimationController _scanController;
  late Animation<double> _scanAnim;

  @override
  void initState() {
    super.initState();
    _tts = FlutterTts();
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.5).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));
    _scanController = AnimationController(vsync: this, duration: const Duration(milliseconds: 2500))..repeat(reverse: true);
    _scanAnim = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _scanController, curve: Curves.easeInOut));

    _initCamera();
    _initTts();
    _phase = InterviewPhase.faceCapture;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _warningTimer?.cancel();
    _cameraController?.dispose();
    _tts.stop();
    _pulseController.dispose();
    _scanController.dispose();
    super.dispose();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      final front = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      _cameraController = CameraController(front, ResolutionPreset.medium, enableAudio: true);
      await _cameraController!.initialize();
      if (mounted) setState(() => _cameraReady = true);
    } catch (e) {
      debugPrint('[CAMERA] Init error: $e');
    }
  }

  Future<void> _initTts() async {
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.45);
    await _tts.setPitch(1.0);
    _tts.setCompletionHandler(() {
      if (_phase == InterviewPhase.speaking) {
        _beginRecording();
      }
    });
  }

  Future<void> _initInterview() async {
    try {
      final result = await InterviewService.startInterview(widget.setup);
      if (mounted) {
        setState(() {
          _sessionId = result.sessionId;
          _questions.addAll(result.questions);
          _phase = InterviewPhase.speaking;
        });
        _speakCurrentQuestion();
      }
    } catch (e) {
      debugPrint('[INIT] Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start: $e'), backgroundColor: AppColors.error),
        );
        setState(() => _phase = InterviewPhase.done);
      }
    }
  }

  void _speakCurrentQuestion() {
    if (_currentIdx >= _questions.length) return;
    final q = _questions[_currentIdx];
    _tts.speak(q.questionText);
  }

  Future<void> _captureBaselineAndStart() async {
    if (_cameraController == null || !_cameraReady) return;
    try {
      final xfile = await _cameraController!.takePicture();
      setState(() {
        _baselineImagePath = xfile.path;
        _phase = InterviewPhase.init;
      });
      await _initInterview();
    } catch (e) {
      debugPrint('[FACE] Baseline capture error: $e');
    }
  }

  Future<void> _beginRecording() async {
    if (_cameraController == null || _isRecording || !_cameraReady) return;

    _isRecording = true;
    setState(() {
      _phase = InterviewPhase.recording;
      _elapsedSec = 0;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsedSec++);
    });

    try {
      await _cameraController!.startVideoRecording();
    } catch (e) {
      debugPrint('[REC] Start error: $e');
      _isRecording = false;
      _timer?.cancel();
    }
  }

  Future<void> _stopRecording() async {
    if (_cameraController == null || !_isRecording) return;
    _timer?.cancel();
    _isRecording = false;

    try {
      final file = await _cameraController!.stopVideoRecording();
      
      // Face Verification after stopping video
      String? currentPicPath;
      if (_baselineImagePath != null) {
        try {
          final pic = await _cameraController!.takePicture();
          currentPicPath = pic.path;
        } catch (e) {
          debugPrint('[FACE] error capturing check photo: $e');
        }
      }

      await _processAnswer(file.path, currentPicPath);
    } catch (e) {
      debugPrint('[REC] Stop error: $e');
    }
  }

  Future<void> _processAnswer(String videoPath, String? currentPicPath) async {
    setState(() => _phase = InterviewPhase.analyzing);
    final currentQ = _questions[_currentIdx];

    // Check Face in parallel or sequentially
    if (currentPicPath != null && _baselineImagePath != null) {
      try {
        final verified = await InterviewService.verifyFace(_baselineImagePath!, currentPicPath);
        if (!verified) {
          _triggerFaceWarning(videoPath);
          return; // Stop processing and wait for user to return
        }
      } catch (e) {
        debugPrint('[FACE] Verification error: $e');
        _triggerFaceWarning(videoPath);
        return;
      }
    }

    try {
      if (_sessionId != null && currentQ.id != null) {
        final result = await InterviewService.submitAnswer(_sessionId!, currentQ.id!, videoPath);

        if (result.nextQuestion != null) {
          setState(() {
            _questions.add(result.nextQuestion!);
            _currentIdx++;
            _phase = InterviewPhase.speaking;
          });
          _speakCurrentQuestion();
        } else {
          await _finishInterview();
        }
      } else {
        await _finishInterview();
      }
    } catch (e) {
      debugPrint('[SUBMIT] Error (offline?): $e');
      // Offline fallback
      final offlineIdx = _currentIdx - 1;
      if (offlineIdx >= 0 && offlineIdx < _offlineQuestions.length && _currentIdx < 4) {
        setState(() {
          _questions.add(_offlineQuestions[offlineIdx]);
          _currentIdx++;
          _phase = InterviewPhase.speaking;
        });
        _speakCurrentQuestion();
      } else {
        await _finishInterview();
      }
    }
  }

  Future<void> _finishInterview() async {
    setState(() => _phase = InterviewPhase.done);
    try {
      if (_sessionId != null) {
        await InterviewService.completeInterview(_sessionId!);
      }
    } catch (e) {
      debugPrint('[COMPLETE] Error: $e');
    }

    // If this is a company screening, update application row after result is available
    if (widget.applicationId != null && widget.applicationId!.isNotEmpty && _sessionId != null) {
      _pollAndUpdateApplication(_sessionId!, widget.applicationId!, widget.jobScoreThreshold ?? 60);
    }

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => InterviewResultsPage(
            sessionId: _sessionId ?? '',
            applicationId: widget.applicationId,
            scoreThreshold: widget.jobScoreThreshold,
          ),
        ),
      );
    }
  }

  /// Poll for results in background and update job_applications
  Future<void> _pollAndUpdateApplication(String sessionId, String appId, int threshold) async {
    for (int i = 0; i < 30; i++) {
      await Future.delayed(const Duration(seconds: 3));
      try {
        final result = await InterviewService.getResult(sessionId);
        if (result.processingComplete && result.compositeScore != null) {
          final passed = result.compositeScore! >= threshold;
          await Supabase.instance.client.from('job_applications').update({
            'ai_session_id': sessionId,
            'ai_composite_score': result.compositeScore,
            'ai_performance_tier': result.performanceTier,
            'ai_screening_passed': passed,
            'status': passed ? 'ai_passed' : 'ai_failed',
          }).eq('id', appId);
          return;
        }
      } catch (e) {
        debugPrint('[POLL-APP] Error: $e');
      }
    }
  }

  // ── CHEATING DETECTION LOGIC ───────────────────────────────────────────────

  void _triggerFaceWarning(String videoPath) {
    if (_faceMismatchWarning) return;
    setState(() {
      _faceMismatchWarning = true;
      _warningCountdown = 10;
    });
    
    _warningTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      try {
        final currentFile = await _cameraController!.takePicture();
        final verified = await InterviewService.verifyFace(_baselineImagePath!, currentFile.path);
        
        if (verified) {
          timer.cancel();
          if (mounted) {
            setState(() {
              _faceMismatchWarning = false;
            });
            // Face verified! Resume uploading video
            _processAnswer(videoPath, null);
          }
          return;
        }
      } catch (_) {}
      
      if (mounted) {
        setState(() => _warningCountdown -= 2);
        if (_warningCountdown <= 0) {
          timer.cancel();
          _markCheatingAndExit();
        }
      }
    });
  }

  Future<void> _markCheatingAndExit() async {
    // 1. Mark the session as cheating on backend
    if (_sessionId != null) {
      try {
        await InterviewService.markCheating(_sessionId!);
      } catch (_) {}
    }

    // 2. Increment cheat_count in job_applications and reset status so user can retry
    if (widget.applicationId != null && widget.applicationId!.isNotEmpty) {
      try {
        final db = Supabase.instance.client;
        // Read current count
        final row = await db.from('job_applications')
            .select('cheat_count')
            .eq('id', widget.applicationId!)
            .maybeSingle();
        final currentCount = (row?['cheat_count'] as int?) ?? 0;
        // Increment and reset status back to ai_screening so they can retry
        await db.from('job_applications').update({
          'cheat_count': currentCount + 1,
          'status': 'ai_screening',          // reset so user can retry
          'ai_session_id': null,             // clear old session
        }).eq('id', widget.applicationId!);
      } catch (e) {
        debugPrint('[CHEAT] DB update error: $e');
      }
    }

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Interview Terminated: Face mismatch / Cheating detected. You may retry from the job listing.', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          backgroundColor: AppColors.error,
          duration: Duration(seconds: 5),
        ),
      );
    }
  }

  String _formatTime(int s) => '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    if (_phase == InterviewPhase.init) {
      return Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(width: 48, height: 48, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white)),
              const SizedBox(height: 20),
              const Text('INITIALIZING AI INTERVIEW...', style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 2)),
              const SizedBox(height: 8),
              Text('ADAPTIVE MODE: 5–12 QUESTIONS', style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 11, letterSpacing: 1)),
            ],
          ),
        ),
      );
    }

    final currentQ = _currentIdx < _questions.length ? _questions[_currentIdx] : null;
    final questionText = currentQ?.questionText ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
            // Progress bar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 6),
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: ((_currentIdx + 1) / 5).clamp(0.0, 1.0),
                      minHeight: 3,
                      backgroundColor: Colors.white.withValues(alpha: 0.08),
                      valueColor: const AlwaysStoppedAnimation(Colors.white),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'QUESTION ${_currentIdx + 1} • AI ADAPTIVE',
                    style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.35), fontWeight: FontWeight.w800, letterSpacing: 2),
                  ),
                ],
              ),
            ),

            // Question card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4)),
                      child: Text('Q${_currentIdx + 1}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.black)),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      questionText,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white, height: 1.5),
                    ),
                  ],
                ),
              ),
            ),

            // Camera feed
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black,
                      border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Stack(
                      children: [
                        // Camera preview
                        if (_cameraReady && _cameraController != null)
                          Positioned.fill(child: CameraPreview(_cameraController!))
                        else
                          Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(LucideIcons.videoOff, color: Colors.white.withValues(alpha: 0.3), size: 40),
                                const SizedBox(height: 12),
                                Text('LOADING CAMERA...', style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 11, letterSpacing: 2)),
                              ],
                            ),
                          ),

                        // HUD corners
                        Positioned(top: 8, left: 8, child: _hudCorner(true, true)),
                        Positioned(top: 8, right: 8, child: _hudCorner(true, false)),
                        Positioned(bottom: 8, left: 8, child: _hudCorner(false, true)),
                        Positioned(bottom: 8, right: 8, child: _hudCorner(false, false)),

                        // Face oval guide
                        Center(
                          child: Container(
                            width: 140, height: 200,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(70),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.15), width: 1, strokeAlign: BorderSide.strokeAlignOutside),
                            ),
                          ),
                        ),

                        // REC badge
                        if (_phase == InterviewPhase.recording)
                          Positioned(
                            top: 16, left: 16,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.7),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  AnimatedBuilder(
                                    animation: _pulseAnim,
                                    builder: (_, __) => Transform.scale(
                                      scale: _pulseAnim.value,
                                      child: Container(width: 8, height: 8, decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.error)),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const Text('REC', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
                                  const SizedBox(width: 6),
                                  Text(_formatTime(_elapsedSec), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700, fontFamily: 'monospace')),
                                ],
                              ),
                            ),
                          ),

                        // Scan line
                        if (_phase == InterviewPhase.recording)
                          Positioned(
                            top: 0, left: 0, right: 0, bottom: 0,
                            child: AnimatedBuilder(
                              animation: _scanAnim,
                              builder: (_, __) => Align(
                                alignment: Alignment(0, -1 + _scanAnim.value * 2),
                                child: Container(height: 2, width: double.infinity, color: Colors.white.withValues(alpha: 0.25)),
                              ),
                            ),
                          ),

                        // Analyzing overlay
                        if (_phase == InterviewPhase.analyzing)
                          Positioned.fill(
                            child: Container(
                              color: Colors.black.withValues(alpha: 0.75),
                              child: const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(width: 36, height: 36, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white)),
                                  SizedBox(height: 16),
                                  Text('ANALYZING RESPONSE...', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: 2)),
                                  SizedBox(height: 6),
                                  Text('AI is deciding the next question', style: TextStyle(color: Colors.white54, fontSize: 11, letterSpacing: 1)),
                                ],
                              ),
                            ),
                          ),

                        // Speaking overlay
                        if (_phase == InterviewPhase.speaking)
                          Positioned(
                            bottom: 16, left: 16, right: 16,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.7),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(LucideIcons.volume2, color: Colors.white, size: 20),
                                  const SizedBox(width: 10),
                                  const Text('AI IS ASKING...', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1)),
                                  const Spacer(),
                                  // Animated bars
                                  ...List.generate(4, (i) => Padding(
                                    padding: const EdgeInsets.only(left: 3),
                                    child: AnimatedBuilder(
                                      animation: _pulseAnim,
                                      builder: (_, __) => Container(
                                        width: 3,
                                        height: 8 + (_pulseAnim.value - 1) * (i + 1) * 8,
                                        decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(2)),
                                      ),
                                    ),
                                  )),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Controls
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: _buildControls(),
            ),
              ],
            ),
          ),
          if (_faceMismatchWarning) _buildCheatingWarningOverlay(),
        ],
      ),
    );
  }

  Widget _buildControls() {
    switch (_phase) {
      case InterviewPhase.faceCapture:
        return GestureDetector(
          onTap: _captureBaselineAndStart,
          child: Container(
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 10)],
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(LucideIcons.camera, color: Colors.white, size: 22),
                SizedBox(width: 10),
                Text('CAPTURE SELFIE TO START', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 1)),
              ],
            ),
          ),
        );
      case InterviewPhase.recording:
        return GestureDetector(
          onTap: _stopRecording,
          child: Container(
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.stop_rounded, color: Colors.white, size: 22),
                SizedBox(width: 10),
                Text('STOP & SUBMIT', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 1)),
              ],
            ),
          ),
        );
      case InterviewPhase.speaking:
        return Container(
          height: 56,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(LucideIcons.volume2, color: Colors.white.withValues(alpha: 0.4), size: 18),
              const SizedBox(width: 10),
              Text('LISTENING TO QUESTION...', style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1)),
            ],
          ),
        );
      case InterviewPhase.analyzing:
        return Container(
          height: 56,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white.withValues(alpha: 0.4))),
              const SizedBox(width: 10),
              Text('AI PROCESSING...', style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1)),
            ],
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _hudCorner(bool top, bool left) {
    return Container(
      width: 20, height: 20,
      decoration: BoxDecoration(
        border: Border(
          top: top ? const BorderSide(color: Colors.white, width: 2) : BorderSide.none,
          bottom: !top ? const BorderSide(color: Colors.white, width: 2) : BorderSide.none,
          left: left ? const BorderSide(color: Colors.white, width: 2) : BorderSide.none,
          right: !left ? const BorderSide(color: Colors.white, width: 2) : BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildCheatingWarningOverlay() {
    return Container(
      color: Colors.black87,
      width: double.infinity,
      height: double.infinity,
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 32),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: AppColors.surfaceDark,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.error, width: 2),
            boxShadow: [
              BoxShadow(color: AppColors.error.withValues(alpha: 0.3), blurRadius: 30, spreadRadius: 5),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(LucideIcons.shieldAlert, color: AppColors.error, size: 64),
              const SizedBox(height: 24),
              const Text(
                'IDENTITY VERIFICATION FAILED',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.error, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 1),
              ),
              const SizedBox(height: 16),
              const Text(
                'A face mismatch or missing face was detected. Please return to the camera immediately to continue your interview.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: AppColors.error,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$_warningCountdown',
                  style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Seconds remaining before termination', style: TextStyle(color: AppColors.error, fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }
}
