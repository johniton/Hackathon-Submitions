import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:hustlr/core/theme/app_colors.dart';
import 'package:hustlr/features/flashcards/data/ai_flashcard_service.dart';
import 'package:hustlr/features/flashcards/presentation/pages/deck_view_page.dart';
import 'package:hustlr/features/flashcards/presentation/pages/assessment_view_page.dart';
import 'package:hustlr/features/learn_skills/presentation/pages/practical_projects_page.dart';
import 'package:hustlr/features/learn_skills/data/roadmap_service.dart';
import 'package:hustlr/features/learn_skills/data/youtube_service.dart';
import 'package:hustlr/features/learn_skills/data/streak_service.dart';
import 'package:hustlr/features/learn_skills/data/practical_project_service.dart';

class RoadmapTopicsPage extends StatefulWidget {
  final UserRoadmap roadmap;
  const RoadmapTopicsPage({super.key, required this.roadmap});

  @override
  State<RoadmapTopicsPage> createState() => _RoadmapTopicsPageState();
}

class _RoadmapTopicsPageState extends State<RoadmapTopicsPage>
    with TickerProviderStateMixin {
  late AnimationController _progressAnimController;
  double _animatedProgress = 0;

  // YouTube
  List<YouTubeVideo> _videos = [];
  bool _loadingVideos = false;
  String? _lastVideoTopic;

  // Flashcards
  FlashcardSessionResult? _lastFlashcardResult;

  List<RoadmapTopic> get _topics => widget.roadmap.topics ?? [];

  @override
  void initState() {
    super.initState();
    _progressAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _animatedProgress = _completionProgress;
    _fetchVideosForCurrentTopic();
  }

  Future<void> _recordActivity() async {
    await StreakService.recordActivity();
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _progressAnimController.dispose();
    super.dispose();
  }

  // ── Progress helpers ──

  double get _completionProgress {
    if (_topics.isEmpty) return 0;
    int total = 0, completed = 0;
    for (final t in _topics) {
      if (t.subtopics.isEmpty) {
        total++;
        if (t.isCompleted) completed++;
      } else {
        for (final s in t.subtopics) {
          total++;
          if (s.isCompleted) completed++;
        }
      }
    }
    return total == 0 ? 0 : completed / total;
  }

  int get _totalItems {
    int t = 0;
    for (final topic in _topics) {
      t += topic.subtopics.isEmpty ? 1 : topic.subtopics.length;
    }
    return t;
  }

  int get _completedItems {
    int c = 0;
    for (final topic in _topics) {
      if (topic.subtopics.isEmpty) {
        if (topic.isCompleted) c++;
      } else {
        c += topic.subtopics.where((s) => s.isCompleted).length;
      }
    }
    return c;
  }

  int get _currentTopicIndex => widget.roadmap.currentTopicIndex;

  bool _isTopicLocked(int index) => index > _currentTopicIndex;

  bool _isTopicFullyDone(RoadmapTopic topic) {
    if (topic.subtopics.isEmpty) return topic.isCompleted;
    return topic.subtopics.every((s) => s.isCompleted);
  }

  // ── Animation ──

  void _animateProgress() {
    final target = _completionProgress;
    final tween = Tween<double>(begin: _animatedProgress, end: target);
    _progressAnimController.reset();
    _progressAnimController.addListener(() {
      setState(
        () => _animatedProgress = tween.evaluate(_progressAnimController),
      );
    });
    _progressAnimController.forward();
  }

  // ── Toggle logic (sequential) ──

  void _toggleTopic(RoadmapTopic topic, int topicIndex) {
    if (_isTopicLocked(topicIndex)) return;
    final markingDone = !topic.isCompleted;
    setState(() => topic.isCompleted = !topic.isCompleted);
    _animateProgress();
    _fetchVideosForCurrentTopic();
    if (markingDone) _recordActivity();
  }

  void _toggleSubtopic(RoadmapTopic subtopic, int parentIndex) {
    if (_isTopicLocked(parentIndex)) return;
    final markingDone = !subtopic.isCompleted;
    setState(() => subtopic.isCompleted = !subtopic.isCompleted);
    // Auto-complete parent if all subs done
    final parent = _topics[parentIndex];
    parent.isCompleted = parent.subtopics.every((s) => s.isCompleted);
    _animateProgress();
    _fetchVideosForCurrentTopic();
    if (markingDone) _recordActivity();
  }

  void _toggleAllSubtopics(RoadmapTopic topic, int topicIndex) {
    if (_isTopicLocked(topicIndex)) return;
    final allDone = topic.subtopics.every((s) => s.isCompleted);
    final markingDone = !allDone; // if not all done, we're marking done
    setState(() {
      for (final s in topic.subtopics) {
        s.isCompleted = !allDone;
      }
      topic.isCompleted = !allDone;
    });
    _animateProgress();
    _fetchVideosForCurrentTopic();
    if (markingDone) _recordActivity();
  }

  // ── YouTube ──

  Future<void> _fetchVideosForCurrentTopic() async {
    final label = widget.roadmap.currentTopicLabel;
    if (label == null || label == _lastVideoTopic) return;
    _lastVideoTopic = label;
    setState(() => _loadingVideos = true);

    final videos = await YouTubeService.searchVideos(
      topic: label,
      roadmapName: widget.roadmap.name,
      maxResults: 3,
    );

    if (mounted) {
      setState(() {
        _videos = videos;
        _loadingVideos = false;
      });
    }
  }

  Future<void> _openVideo(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _openPracticalProjects() async {
    final skillOrRole = widget.roadmap.targetSkill ?? widget.roadmap.targetRole ?? widget.roadmap.name;
    final topics = _topics.map((t) => t.label).toList();
    if (topics.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No roadmap topics available for practical work.')),
      );
      return;
    }

    // Try load cached pack first
    PracticalProjectPack? pack = await PracticalProjectService.loadPracticalProjectPack(widget.roadmap.name, skillOrRole);
    if (pack != null) {
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PracticalProjectsPage(pack: pack!, skillLabel: skillOrRole),
        ),
      );
      return;
    }

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      pack = await AiFlashcardService.generatePracticalProjects(
        roadmapName: widget.roadmap.name,
        skillOrRole: skillOrRole,
        topics: topics,
      );
      // persist so repeated opens show the same projects
      await PracticalProjectService.persistPracticalProjectPack(widget.roadmap.name, skillOrRole, pack);
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Practical projects failed: $e')),
        );
      }
      return;
    }

    if (!mounted) return;
    Navigator.pop(context);

    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PracticalProjectsPage(pack: pack!, skillLabel: skillOrRole),
      ),
    );
  }

  // ── Build ──

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final progress = _completionProgress;
    final pct = (progress * 100).toInt();

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openPracticalProjects,
        icon: const Icon(LucideIcons.briefcase, size: 18),
        label: const Text('Practical Work'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            _buildHeader(isDark),
            _buildGoalCard(isDark),
            _buildProgressCard(isDark, pct, progress),
            _buildAiFlashcardsSection(isDark),
            if (widget.roadmap.skillGaps.isNotEmpty) _buildSkillGaps(isDark),
            _buildYouTubeSection(isDark),
            _buildTopicsHeader(isDark),
            _buildTopicsList(isDark),
            const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        ),
      ),
    );
  }

  // ── Header ──

  SliverToBoxAdapter _buildHeader(bool isDark) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: Row(
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceDark2 : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  LucideIcons.arrowLeft,
                  size: 20,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                '${widget.roadmap.name} Roadmap',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Goal Card ──

  SliverToBoxAdapter _buildGoalCard(bool isDark) {
    final r = widget.roadmap;
    if (r.targetRole == null && r.targetCompany == null) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? Colors.white10
                  : Colors.black.withValues(alpha: 0.06),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(LucideIcons.target, size: 16, color: AppColors.primary),
                  SizedBox(width: 8),
                  Text(
                    'Your Goal',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _goalRow(
                LucideIcons.calendar,
                'Estimated Time',
                '${(widget.roadmap.topics?.length ?? 1) * 3} days to complete',
                isDark,
              ),
              if (r.targetRole != null)
                _goalRow(
                  LucideIcons.briefcase,
                  'Target Role',
                  r.targetRole!,
                  isDark,
                ),
              if (r.targetCompany != null)
                _goalRow(
                  LucideIcons.building2,
                  'Target Company',
                  r.targetCompany!,
                  isDark,
                ),
              if (r.targetSkill != null)
                _goalRow(
                  LucideIcons.zap,
                  'Target Skill',
                  r.targetSkill!,
                  isDark,
                ),
              const SizedBox(height: 10),
              if (r.targetRole != null || r.targetSkill != null)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _startSkillAssessment,
                    icon: const Icon(LucideIcons.activity, size: 16),
                    label: const Text('Take Skill Assessment'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _goalRow(IconData icon, String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 14, color: AppColors.textSecondaryLight),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: const TextStyle(
              color: AppColors.textSecondaryLight,
              fontSize: 12,
            ),
          ),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // ── Skill Gaps ──

  SliverToBoxAdapter _buildSkillGaps(bool isDark) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.warning.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.warning.withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(
                    LucideIcons.alertTriangle,
                    size: 16,
                    color: AppColors.warning,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Skill Gaps Identified',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: AppColors.warning,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: widget.roadmap.skillGaps
                    .map(
                      (gap) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppColors.warning.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Text(
                          gap,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.warning,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Progress Card ──

  SliverToBoxAdapter _buildProgressCard(bool isDark, int pct, double progress) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.3),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(
                        LucideIcons.graduationCap,
                        color: Colors.white,
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Your Progress',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$_completedItems / $_totalItems',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text(
                    '$pct%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Complete',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: _animatedProgress,
                  backgroundColor: Colors.white24,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    AppColors.accent,
                  ),
                  minHeight: 8,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── AI Flashcards Section ──

  SliverToBoxAdapter _buildAiFlashcardsSection(bool isDark) {
    final unlocked = _completedItems >= 3;
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? Colors.white10
                  : Colors.black.withValues(alpha: 0.06),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      gradient: AppColors.purpleGradient,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      LucideIcons.sparkles,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'AI Flashcards + Quick Quiz',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  if (!unlocked)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Locked',
                        style: TextStyle(
                          color: AppColors.warning,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: const [
                  _TinyPill('Source of truth: checked topics only'),
                  _TinyPill('Types: Q&A, fill blank, T/F, code output'),
                  _TinyPill('SM-2 scheduling enabled'),
                  _TinyPill('Share/export deck + roadmap feedback'),
                ],
              ),
              const SizedBox(height: 8),
              if (_lastFlashcardResult != null) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'Last quiz: ${_lastFlashcardResult!.accuracyPercent.toStringAsFixed(0)}% accuracy, ${_lastFlashcardResult!.totalPoints} points',
                    style: const TextStyle(
                      color: AppColors.accent,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: unlocked ? _openAiFlashcardsGenerator : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.primary.withValues(
                      alpha: 0.35,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(LucideIcons.bot, size: 17),
                  label: const Text(
                    'Generate AI Flashcards',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<String> _completedTopicLabels() {
    final labels = <String>[];
    for (final topic in _topics) {
      if (topic.subtopics.isEmpty) {
        if (topic.isCompleted) labels.add(topic.label);
      } else {
        for (final sub in topic.subtopics) {
          if (sub.isCompleted) labels.add('${topic.label}: ${sub.label}');
        }
      }
    }
    return labels;
  }

  Future<void> _openAiFlashcardsGenerator() async {
    final completedTopics = _completedTopicLabels();
    if (completedTopics.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mark some topics complete before generating quiz.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    FlashcardSourceType sourceType = FlashcardSourceType.roadmapTopic;
    final selectedTypes = <FlashcardQuestionType>{
      FlashcardQuestionType.qa,
      FlashcardQuestionType.fillInBlank,
      FlashcardQuestionType.trueFalse,
      FlashcardQuestionType.codeOutput,
    };

    final notesController = TextEditingController();
    final transcriptController = TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final isDark = Theme.of(ctx).brightness == Brightness.dark;
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceDark : Colors.white,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(22),
                  ),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Create AI Flashcard Deck',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 17,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Questions will be generated only from checked topics (${completedTopics.length}).',
                        style: const TextStyle(
                          color: AppColors.textSecondaryLight,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Source Option',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _sourceChip(
                            'Roadmap Topic',
                            sourceType == FlashcardSourceType.roadmapTopic,
                            () => setSheetState(
                              () =>
                                  sourceType = FlashcardSourceType.roadmapTopic,
                            ),
                          ),
                          _sourceChip(
                            'Pasted Notes',
                            sourceType == FlashcardSourceType.pastedNotes,
                            () => setSheetState(
                              () =>
                                  sourceType = FlashcardSourceType.pastedNotes,
                            ),
                          ),
                          _sourceChip(
                            'YouTube Transcript URL',
                            sourceType == FlashcardSourceType.youtubeTranscript,
                            () => setSheetState(
                              () => sourceType =
                                  FlashcardSourceType.youtubeTranscript,
                            ),
                          ),
                          _sourceChip(
                            'Upload PDF/Notes',
                            sourceType == FlashcardSourceType.uploadedNotes,
                            () => setSheetState(
                              () => sourceType =
                                  FlashcardSourceType.uploadedNotes,
                            ),
                          ),
                        ],
                      ),
                      if (sourceType == FlashcardSourceType.uploadedNotes)
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: OutlinedButton.icon(
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'File upload hook can be connected next. For now, paste notes below.',
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(LucideIcons.upload, size: 16),
                            label: const Text('Choose PDF/Notes (placeholder)'),
                          ),
                        ),
                      const SizedBox(height: 14),
                      const Text(
                        'Question Types',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _typeChip(
                            'Q&A',
                            FlashcardQuestionType.qa,
                            selectedTypes,
                            setSheetState,
                          ),
                          _typeChip(
                            'Fill in blank',
                            FlashcardQuestionType.fillInBlank,
                            selectedTypes,
                            setSheetState,
                          ),
                          _typeChip(
                            'True / False',
                            FlashcardQuestionType.trueFalse,
                            selectedTypes,
                            setSheetState,
                          ),
                          _typeChip(
                            'Code output',
                            FlashcardQuestionType.codeOutput,
                            selectedTypes,
                            setSheetState,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: notesController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: 'Paste notes/content (optional)',
                          filled: true,
                          fillColor: isDark
                              ? AppColors.surfaceDark2
                              : Colors.grey.shade100,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: transcriptController,
                        decoration: InputDecoration(
                          hintText: 'YouTube transcript URL (optional)',
                          filled: true,
                          fillColor: isDark
                              ? AppColors.surfaceDark2
                              : Colors.grey.shade100,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            Navigator.pop(ctx);
                            final navigator = Navigator.of(context);
                            FlashcardDeck deck;
                            try {
                              deck = await AiFlashcardService.generateDeck(
                                roadmapName: widget.roadmap.name,
                                topicLabel: widget.roadmap.name,
                                completedTopics: completedTopics,
                                questionTypes: selectedTypes,
                                sourceType: sourceType,
                                notes: notesController.text,
                                youtubeTranscriptUrl: transcriptController.text,
                              );
                            } catch (e) {
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Gemini generation failed: $e'),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                              return;
                            }

                            final result = await navigator.push(
                              MaterialPageRoute(
                                builder: (_) => DeckViewPage(deck: deck),
                              ),
                            );

                            if (!mounted || result is! FlashcardSessionResult) {
                              return;
                            }

                            setState(() => _lastFlashcardResult = result);
                            _applyFlashcardPerformanceToRoadmap(result);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(LucideIcons.playCircle, size: 17),
                          label: const Text('Start Quiz'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _startSkillAssessment() async {
    int numQuestions = 10;
    int timeMinutes = 15;
    String difficulty = 'Medium';

    final started = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final isDark = Theme.of(ctx).brightness == Brightness.dark;
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceDark : Colors.white,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Configure Assessment', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 20),
                    const Text('Number of Questions', style: TextStyle(fontWeight: FontWeight.w600)),
                    Slider(
                      value: numQuestions.toDouble(),
                      min: 5, max: 20, divisions: 3,
                      label: '$numQuestions',
                      onChanged: (v) => setSheetState(() => numQuestions = v.toInt()),
                    ),
                    const SizedBox(height: 10),
                    const Text('Time Limit (Minutes)', style: TextStyle(fontWeight: FontWeight.w600)),
                    Slider(
                      value: timeMinutes.toDouble(),
                      min: 5, max: 60, divisions: 11,
                      label: '$timeMinutes',
                      onChanged: (v) => setSheetState(() => timeMinutes = v.toInt()),
                    ),
                    const SizedBox(height: 10),
                    const Text('Difficulty', style: TextStyle(fontWeight: FontWeight.w600)),
                    DropdownButton<String>(
                      value: difficulty,
                      isExpanded: true,
                      items: ['Easy', 'Medium', 'Hard'].map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                      onChanged: (v) => setSheetState(() => difficulty = v!),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Start Assessment', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (started != true) return;

    final skillOrRole = widget.roadmap.targetSkill ?? widget.roadmap.targetRole ?? widget.roadmap.name;
    final topics = _topics.map((t) => t.label).toList();
    if (topics.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No topics available for assessment.')),
      );
      return;
    }

    // Show blocking progress dialog while generating
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final deck = await AiFlashcardService.generateAssessmentDeck(
        roadmapName: widget.roadmap.name,
        skillOrRole: '$skillOrRole (Difficulty: $difficulty)',
        topics: topics,
        numQuestions: numQuestions,
        questionTypes: {
          FlashcardQuestionType.qa,
          FlashcardQuestionType.fillInBlank,
          FlashcardQuestionType.trueFalse,
        },
      );
      if (mounted) Navigator.pop(context);

      if (!mounted) return;
      final result = await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => AssessmentViewPage(deck: deck)), // Assessment limit could be implemented internally
      );

      if (!mounted || result is! FlashcardSessionResult) return;

      _applyAssessmentToRoadmap(result);
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to generate: $e')));
      }
    }
  }

  void _applyAssessmentToRoadmap(FlashcardSessionResult result) {
    final acc = result.accuracyPercent;
    final total = _totalItems;
    int steps = 0;
    if (acc >= 85) {
      steps = (total * 0.35).round();
    } else if (acc >= 65) {
      steps = (total * 0.15).round();
    } else if (acc >= 50) {
      steps = (total * 0.08).round();
    } else {
      steps = 0;
    }

    if (steps <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Assessment saved (${acc.toStringAsFixed(0)}%). No roadmap change.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    steps = steps.clamp(1, total);
    bool changed = false;
    var remaining = steps;

    setState(() {
      for (int i = _currentTopicIndex; i < _topics.length && remaining > 0; i++) {
        final topic = _topics[i];
        if (topic.subtopics.isEmpty) {
          if (!topic.isCompleted) {
            topic.isCompleted = true;
            changed = true;
            remaining--;
          }
        } else {
          for (final sub in topic.subtopics) {
            if (!sub.isCompleted && remaining > 0) {
              sub.isCompleted = true;
              remaining--;
              changed = true;
            }
          }
          topic.isCompleted = topic.subtopics.every((s) => s.isCompleted);
        }
      }
    });

    if (changed) {
      _animateProgress();
      _fetchVideosForCurrentTopic();
      _recordActivity();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Assessment boosted roadmap by $steps step(s).'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Assessment finished (${acc.toStringAsFixed(0)}%). No new steps available.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Widget _sourceChip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.15)
              : AppColors.primary.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.6)
                : AppColors.primary.withValues(alpha: 0.2),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? AppColors.primary : AppColors.textSecondaryLight,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _typeChip(
    String label,
    FlashcardQuestionType type,
    Set<FlashcardQuestionType> selected,
    StateSetter setSheetState,
  ) {
    final isSelected = selected.contains(type);
    return GestureDetector(
      onTap: () {
        setSheetState(() {
          if (isSelected && selected.length > 1) {
            selected.remove(type);
          } else if (!isSelected) {
            selected.add(type);
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.accent.withValues(alpha: 0.15)
              : AppColors.accent.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? AppColors.accent.withValues(alpha: 0.6)
                : AppColors.accent.withValues(alpha: 0.2),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? AppColors.accent : AppColors.textSecondaryLight,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  void _applyFlashcardPerformanceToRoadmap(FlashcardSessionResult result) {
    final boostEligible = result.accuracyPercent >= 70;
    if (!boostEligible) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Quiz saved (${result.accuracyPercent.toStringAsFixed(0)}%). Score 70%+ to auto-boost roadmap progress.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_currentTopicIndex >= _topics.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Great job. Roadmap is already complete.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    bool changed = false;
    final topic = _topics[_currentTopicIndex];
    setState(() {
      if (topic.subtopics.isEmpty) {
        if (!topic.isCompleted) {
          topic.isCompleted = true;
          changed = true;
        }
      } else {
        RoadmapTopic? nextSub;
        for (final sub in topic.subtopics) {
          if (!sub.isCompleted) {
            nextSub = sub;
            break;
          }
        }
        if (nextSub != null) {
          nextSub.isCompleted = true;
          topic.isCompleted = topic.subtopics.every((s) => s.isCompleted);
          changed = true;
        }
      }
    });

    if (changed) {
      _animateProgress();
      _fetchVideosForCurrentTopic();
      _recordActivity();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Flashcard performance boosted roadmap progress by 1 step.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ── YouTube Section ──

  SliverToBoxAdapter _buildYouTubeSection(bool isDark) {
    final currentLabel = widget.roadmap.currentTopicLabel;
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    LucideIcons.youtube,
                    size: 18,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Recommended Videos',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      if (currentLabel != null)
                        Text(
                          'For: $currentLabel',
                          style: const TextStyle(
                            color: AppColors.textSecondaryLight,
                            fontSize: 11,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_loadingVideos)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.red,
                    ),
                  ),
                ),
              )
            else if (_videos.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceDark : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark
                        ? Colors.white10
                        : Colors.black.withValues(alpha: 0.05),
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      LucideIcons.videoOff,
                      size: 28,
                      color: AppColors.textSecondaryLight.withValues(
                        alpha: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      YouTubeService.apiKey.isEmpty
                          ? 'Add YOUTUBE_API_KEY to .env to see video suggestions'
                          : 'No videos found for this topic',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.textSecondaryLight,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              )
            else
              SizedBox(
                height: 160,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _videos.length,
                  separatorBuilder: (c, i2) => const SizedBox(width: 12),
                  itemBuilder: (_, i) => _buildVideoCard(_videos[i], isDark),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoCard(YouTubeVideo video, bool isDark) {
    return GestureDetector(
      onTap: () => _openVideo(video.watchUrl),
      child: Container(
        width: 220,
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark
                ? Colors.white10
                : Colors.black.withValues(alpha: 0.06),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(14),
              ),
              child: video.thumbnailUrl.isNotEmpty
                  ? Image.network(
                      video.thumbnailUrl,
                      width: 220,
                      height: 100,
                      fit: BoxFit.cover,
                      errorBuilder: (ctx, err, st) => Container(
                        width: 220,
                        height: 100,
                        color: Colors.grey.shade300,
                        child: const Icon(
                          LucideIcons.image,
                          color: Colors.grey,
                        ),
                      ),
                    )
                  : Container(
                      width: 220,
                      height: 100,
                      color: Colors.grey.shade300,
                      child: const Icon(LucideIcons.image, color: Colors.grey),
                    ),
            ),
            // Title
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        video.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        const Icon(
                          LucideIcons.youtube,
                          size: 10,
                          color: Colors.red,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            video.channelTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 9,
                              color: AppColors.textSecondaryLight,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Topics Header ──

  SliverToBoxAdapter _buildTopicsHeader(bool isDark) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        child: Row(
          children: [
            Text(
              'Topics',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${_topics.length}',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const Spacer(),
            Row(
              children: [
                Icon(
                  LucideIcons.lock,
                  size: 12,
                  color: AppColors.textSecondaryLight.withValues(alpha: 0.6),
                ),
                const SizedBox(width: 4),
                Text(
                  'Sequential unlock',
                  style: TextStyle(
                    color: AppColors.textSecondaryLight.withValues(alpha: 0.6),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Topics List ──

  SliverList _buildTopicsList(bool isDark) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) => _buildTopicCard(_topics[index], isDark, index),
        childCount: _topics.length,
      ),
    );
  }

  Widget _buildTopicCard(RoadmapTopic topic, bool isDark, int index) {
    final hasSubs = topic.subtopics.isNotEmpty;
    final isDone = _isTopicFullyDone(topic);
    final locked = _isTopicLocked(index);
    final isCurrent = index == _currentTopicIndex;
    final completedSubCount = topic.subtopics
        .where((s) => s.isCompleted)
        .length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: locked ? 0.45 : 1.0,
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isCurrent
                  ? AppColors.primary.withValues(alpha: 0.5)
                  : isDone
                  ? AppColors.success.withValues(alpha: 0.4)
                  : isDark
                  ? Colors.white10
                  : Colors.black.withValues(alpha: 0.06),
              width: isCurrent ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: isCurrent
                    ? AppColors.primary.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 4,
              ),
              childrenPadding: const EdgeInsets.only(
                left: 16,
                right: 16,
                bottom: 12,
              ),
              leading: GestureDetector(
                onTap: locked
                    ? null
                    : hasSubs
                    ? () => _toggleAllSubtopics(topic, index)
                    : () => _toggleTopic(topic, index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isDone
                        ? AppColors.success
                        : locked
                        ? (isDark
                              ? AppColors.surfaceDark2
                              : Colors.grey.shade200)
                        : isDark
                        ? AppColors.surfaceDark2
                        : Colors.grey.shade100,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDone
                          ? AppColors.success
                          : locked
                          ? AppColors.textSecondaryLight.withValues(alpha: 0.2)
                          : AppColors.textSecondaryLight.withValues(alpha: 0.3),
                      width: 1.5,
                    ),
                  ),
                  child: isDone
                      ? const Icon(
                          LucideIcons.check,
                          color: Colors.white,
                          size: 16,
                        )
                      : locked
                      ? Icon(
                          LucideIcons.lock,
                          size: 12,
                          color: AppColors.textSecondaryLight.withValues(
                            alpha: 0.5,
                          ),
                        )
                      : Center(
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(
                              color: AppColors.textSecondaryLight,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                ),
              ),
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      topic.label,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: isDone
                            ? AppColors.success
                            : locked
                            ? AppColors.textSecondaryLight
                            : null,
                        decoration: isDone ? TextDecoration.lineThrough : null,
                        decorationColor: AppColors.success,
                      ),
                    ),
                  ),
                  if (isCurrent && !isDone)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'Current',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
              subtitle: hasSubs
                  ? Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          Text(
                            '$completedSubCount/${topic.subtopics.length} subtopics',
                            style: const TextStyle(
                              color: AppColors.textSecondaryLight,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: topic.subtopics.isEmpty
                                    ? 0
                                    : completedSubCount /
                                          topic.subtopics.length,
                                backgroundColor: isDark
                                    ? AppColors.surfaceDark2
                                    : Colors.grey.shade200,
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  AppColors.success,
                                ),
                                minHeight: 4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : null,
              trailing: hasSubs ? null : const SizedBox.shrink(),
              children: hasSubs
                  ? topic.subtopics
                        .map(
                          (sub) =>
                              _buildSubtopicTile(sub, isDark, index, locked),
                        )
                        .toList()
                  : [],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSubtopicTile(
    RoadmapTopic subtopic,
    bool isDark,
    int parentIndex,
    bool locked,
  ) {
    return GestureDetector(
      onTap: locked ? null : () => _toggleSubtopic(subtopic, parentIndex),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: subtopic.isCompleted
              ? AppColors.success.withValues(alpha: 0.06)
              : isDark
              ? AppColors.surfaceDark2.withValues(alpha: 0.5)
              : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: subtopic.isCompleted
                ? AppColors.success.withValues(alpha: 0.25)
                : isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: 0.04),
          ),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: subtopic.isCompleted
                    ? AppColors.success
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(7),
                border: Border.all(
                  color: subtopic.isCompleted
                      ? AppColors.success
                      : locked
                      ? AppColors.textSecondaryLight.withValues(alpha: 0.2)
                      : AppColors.textSecondaryLight.withValues(alpha: 0.4),
                  width: 1.5,
                ),
              ),
              child: subtopic.isCompleted
                  ? const Icon(LucideIcons.check, color: Colors.white, size: 14)
                  : locked
                  ? Icon(
                      LucideIcons.lock,
                      size: 10,
                      color: AppColors.textSecondaryLight.withValues(
                        alpha: 0.4,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                subtopic.label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: subtopic.isCompleted
                      ? AppColors.textSecondaryLight
                      : locked
                      ? AppColors.textSecondaryLight
                      : null,
                  decoration: subtopic.isCompleted
                      ? TextDecoration.lineThrough
                      : null,
                  decorationColor: AppColors.textSecondaryLight,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TinyPill extends StatelessWidget {
  final String label;

  const _TinyPill(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.primary,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
