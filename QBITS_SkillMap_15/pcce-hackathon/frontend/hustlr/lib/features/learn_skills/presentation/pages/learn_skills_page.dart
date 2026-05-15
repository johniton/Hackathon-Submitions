import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:hustlr/core/theme/app_colors.dart';
import 'package:hustlr/features/learn_skills/data/roadmap_service.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hustlr/features/learn_skills/data/streak_service.dart';
import 'package:hustlr/features/learn_skills/presentation/pages/roadmap_topics_page.dart';

class LearnSkillsPage extends StatefulWidget {
  const LearnSkillsPage({super.key});

  @override
  State<LearnSkillsPage> createState() => _LearnSkillsPageState();
}

class _LearnSkillsPageState extends State<LearnSkillsPage> {
  final List<UserRoadmap> _userRoadmaps = [];
  StreakData? _streakData;

  @override
  void initState() {
    super.initState();
    _loadStreak();
  }

  Future<void> _loadStreak() async {
    final data = await StreakService.load();
    if (mounted) setState(() => _streakData = data);
  }

  Future<void> _importMissingSkills() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('last_generate_result');
    if (raw == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No resume found. Generate your resume first.')));
      return;
    }

    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final ats = data['ats_score'] as Map<String, dynamic>? ?? {};
      final missing = <String>[];
      if (ats['missing_keywords'] != null && ats['missing_keywords'] is List) {
        for (var s in (ats['missing_keywords'] as List)) {
          if (s is String && s.trim().isNotEmpty) missing.add(s.trim());
        }
      }

      if (missing.isEmpty) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No missing skills detected in resume.')));
        return;
      }

      final toImport = missing.take(5).toList();
      int added = 0;
      for (final label in toImport) {
        final slug = RoadmapService.resolveSlug(label);
        if (_userRoadmaps.any((r) => r.slug == slug)) continue;
        final topics = await RoadmapService.fetchRoadmap(slug);
        if (topics != null && topics.isNotEmpty) {
          final displayName = RoadmapService.displayName(slug);
          final dummyGaps = _generateDummySkillGaps(displayName);
          setState(() {
            _userRoadmaps.add(UserRoadmap(
              name: displayName,
              slug: slug,
              topics: topics,
              isLoaded: true,
              targetRole: 'Senior $displayName Developer',
              targetCompany: _dummyCompanies[_userRoadmaps.length % _dummyCompanies.length],
              targetSkill: displayName,
              skillGaps: dummyGaps,
            ));
          });
          added++;
        }
      }

      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Imported $added skill(s) from resume')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to import skills')));
    }
  }

  void _showAddSkillDialog() {
    final controller = TextEditingController();
    String? errorText;
    bool isLoading = false;

    showModalBottomSheet(
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
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceDark : Colors.white,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Handle bar
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white24 : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Title
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            gradient: AppColors.primaryGradient,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            LucideIcons.plus,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Add a Skill',
                              style: Theme.of(ctx).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const Text(
                              'We\'ll fetch the roadmap from roadmap.sh',
                              style: TextStyle(
                                color: AppColors.textSecondaryLight,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Text field
                    Container(
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.surfaceDark2
                            : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: errorText != null
                              ? AppColors.error.withValues(alpha: 0.5)
                              : isDark
                              ? Colors.white10
                              : Colors.black.withValues(alpha: 0.08),
                        ),
                      ),
                      child: TextField(
                        controller: controller,
                        autofocus: true,
                        textCapitalization: TextCapitalization.words,
                        decoration: InputDecoration(
                          hintText:
                              'e.g. Flutter, Python, System Design, DSA...',
                          hintStyle: TextStyle(
                            color: AppColors.textSecondaryLight.withValues(
                              alpha: 0.6,
                            ),
                            fontSize: 14,
                          ),
                          prefixIcon: Icon(
                            LucideIcons.search,
                            size: 18,
                            color: AppColors.textSecondaryLight,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                        ),
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                          fontSize: 15,
                        ),
                        onSubmitted: (_) {
                          if (!isLoading) {
                            _addSkill(
                              controller.text,
                              ctx,
                              setSheetState,
                              (e) => errorText = e,
                              (l) => isLoading = l,
                            );
                          }
                        },
                      ),
                    ),

                    if (errorText != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(
                            LucideIcons.alertCircle,
                            size: 14,
                            color: AppColors.error,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              errorText!,
                              style: const TextStyle(
                                color: AppColors.error,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],

                    const SizedBox(height: 20),

                    // Add button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: isLoading
                            ? null
                            : () => _addSkill(
                                controller.text,
                                ctx,
                                setSheetState,
                                (e) => errorText = e,
                                (l) => isLoading = l,
                              ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: AppColors.primary.withValues(
                            alpha: 0.5,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        child: isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(LucideIcons.download, size: 18),
                                  SizedBox(width: 8),
                                  Text(
                                    'Fetch Roadmap',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),

                    const SizedBox(height: 8),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _addSkill(
    String input,
    BuildContext ctx,
    StateSetter setSheetState,
    void Function(String?) setError,
    void Function(bool) setLoading,
  ) async {
    final trimmed = input.trim();
    if (trimmed.isEmpty) {
      setSheetState(() => setError('Please enter a skill or role name'));
      return;
    }

    final slug = RoadmapService.resolveSlug(trimmed);

    // Check if already added
    if (_userRoadmaps.any((r) => r.slug == slug)) {
      setSheetState(() => setError('You already have this roadmap'));
      return;
    }

    setSheetState(() {
      setError(null);
      setLoading(true);
    });

    final topics = await RoadmapService.fetchRoadmap(slug);

    if (!mounted) return;

    if (topics == null || topics.isEmpty) {
      setSheetState(() {
        setError(
          'Roadmap not found on roadmap.sh for "$trimmed". Try a different name.',
        );
        setLoading(false);
      });
      return;
    }

    // Successfully fetched — populate with dummy goal data
    final displayName = RoadmapService.displayName(slug);
    final dummyGaps = _generateDummySkillGaps(displayName);
    setState(() {
      _userRoadmaps.add(
        UserRoadmap(
          name: displayName,
          slug: slug,
          topics: topics,
          isLoaded: true,
          targetRole: 'Senior $displayName Developer',
          targetCompany:
              _dummyCompanies[_userRoadmaps.length % _dummyCompanies.length],
          targetSkill: displayName,
          skillGaps: dummyGaps,
        ),
      );
    });

    setSheetState(() => setLoading(false));
    if (ctx.mounted) Navigator.pop(ctx);

    // Show success snackbar
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(
                LucideIcons.checkCircle,
                color: Colors.white,
                size: 18,
              ),
              const SizedBox(width: 10),
              Text('$displayName roadmap added!'),
            ],
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  static const _dummyCompanies = [
    'Google',
    'Microsoft',
    'Amazon',
    'Meta',
    'Apple',
    'Netflix',
    'Spotify',
    'Stripe',
    'Uber',
    'Airbnb',
  ];

  List<String> _generateDummySkillGaps(String skillName) {
    final gapSets = {
      'Flutter': [
        'State Management',
        'Platform Channels',
        'Custom Painting',
        'CI/CD for Mobile',
      ],
      'Python': [
        'Async Programming',
        'Design Patterns',
        'Memory Management',
        'Type Hints',
      ],
      'React': [
        'Server Components',
        'Performance Optimization',
        'Testing Strategies',
        'SSR/SSG',
      ],
      'JavaScript': [
        'Event Loop Internals',
        'Module Systems',
        'Memory Leaks',
        'Web Workers',
      ],
      'DevOps': [
        'Infrastructure as Code',
        'Monitoring & Observability',
        'Security Scanning',
        'GitOps',
      ],
    };
    return gapSets[skillName] ??
        [
          'Advanced Concepts',
          'Best Practices',
          'System Design',
          'Testing & QA',
        ];
  }

  void _removeRoadmap(int index) {
    final name = _userRoadmaps[index].name;
    setState(() => _userRoadmaps.removeAt(index));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$name removed'),
        backgroundColor: AppColors.surfaceDark2,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.surfaceDark2
                            : Colors.grey.shade100,
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Learn Skills',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const Text(
                          'Add skills to generate roadmaps',
                          style: TextStyle(
                            color: AppColors.textSecondaryLight,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: _importMissingSkills,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.surfaceDark2 : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(LucideIcons.filePlus, size: 18, color: isDark ? Colors.white : Colors.black87),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            _buildStreakBanner(isDark),

            const SizedBox(height: 12),

            // Content
            Expanded(
              child: _userRoadmaps.isEmpty
                  ? _buildEmptyState(isDark)
                  : _buildRoadmapList(isDark),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddSkillDialog,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 4,
        icon: const Icon(LucideIcons.plus, size: 20),
        label: const Text(
          'Add Skill',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  Widget _buildStreakBanner(bool isDark) {
    final s = _streakData;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.accentOrange.withValues(alpha: 0.12)
              : AppColors.accentOrange.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.accentOrange.withValues(alpha: 0.25),
          ),
        ),
        child: Row(
          children: [
            Text(
              s == null ? '🔥' : s.streakEmoji,
              style: const TextStyle(fontSize: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s == null
                        ? 'Loading streak...'
                        : s.currentStreak == 0
                        ? 'No active streak'
                        : '${s.currentStreak}-day streak!',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: AppColors.accentOrange,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    s == null
                        ? ''
                        : 'Best: ${s.longestStreak} days  •  ${s.totalTopicsCompleted} topics done',
                    style: TextStyle(
                      color: AppColors.accentOrange.withValues(alpha: 0.75),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            if (s != null && s.isActiveToday)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: AppColors.accentOrange,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  '✓ Today',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                LucideIcons.bookOpen,
                size: 44,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 28),
            Text(
              'No skills added yet',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              'Tap the "Add Skill" button below to search\nfor any skill or role and generate its roadmap\nfrom roadmap.sh',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondaryLight,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            // Suggestion chips
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _suggestionChip('Flutter', isDark),
                _suggestionChip('Python', isDark),
                _suggestionChip('React', isDark),
                _suggestionChip('DSA', isDark),
                _suggestionChip('System Design', isDark),
                _suggestionChip('DevOps', isDark),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Tap a suggestion to quickly add',
              style: TextStyle(
                color: AppColors.textSecondaryLight.withValues(alpha: 0.6),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _suggestionChip(String label, bool isDark) {
    return GestureDetector(
      onTap: () async {
        final slug = RoadmapService.resolveSlug(label);
        if (_userRoadmaps.any((r) => r.slug == slug)) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$label is already added'),
              backgroundColor: AppColors.warning,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
          return;
        }

        final topics = await RoadmapService.fetchRoadmap(slug);
        if (!mounted) return;

        if (topics != null && topics.isNotEmpty) {
          final displayName = RoadmapService.displayName(slug);
          final dummyGaps = _generateDummySkillGaps(displayName);
          setState(() {
            _userRoadmaps.add(
              UserRoadmap(
                name: displayName,
                slug: slug,
                topics: topics,
                isLoaded: true,
                targetRole: 'Senior $displayName Developer',
                targetCompany:
                    _dummyCompanies[_userRoadmaps.length %
                        _dummyCompanies.length],
                targetSkill: displayName,
                skillGaps: dummyGaps,
              ),
            );
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(
                    LucideIcons.checkCircle,
                    color: Colors.white,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Text('$displayName roadmap added!'),
                ],
              ),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark2 : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.1)
                : AppColors.primary.withValues(alpha: 0.2),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: AppColors.primary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildRoadmapList(bool isDark) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: _userRoadmaps.length,
      itemBuilder: (context, index) {
        final roadmap = _userRoadmaps[index];
        return _buildRoadmapTile(roadmap, isDark, index);
      },
    );
  }

  Widget _buildRoadmapTile(UserRoadmap roadmap, bool isDark, int index) {
    final gradients = [
      AppColors.primaryGradient,
      AppColors.tealGradient,
      AppColors.purpleGradient,
      AppColors.orangeGradient,
    ];
    final gradient = gradients[index % gradients.length];
    final gradientColors = gradient.colors;

    // Calculate progress
    int total = 0;
    int completed = 0;
    if (roadmap.topics != null) {
      for (final topic in roadmap.topics!) {
        if (topic.subtopics.isEmpty) {
          total++;
          if (topic.isCompleted) completed++;
        } else {
          for (final sub in topic.subtopics) {
            total++;
            if (sub.isCompleted) completed++;
          }
        }
      }
    }
    final progress = total == 0 ? 0.0 : completed / total;
    final progressPercent = (progress * 100).toInt();

    return Dismissible(
      key: ValueKey(roadmap.slug),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => _removeRoadmap(index),
      background: Container(
        alignment: Alignment.centerRight,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(LucideIcons.trash2, color: Colors.white, size: 22),
      ),
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => RoadmapTopicsPage(roadmap: roadmap),
            ),
          ).then((_) {
            // Refresh UI on return to update progress
            setState(() {});
            _loadStreak();
          });
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? Colors.white10
                  : Colors.black.withValues(alpha: 0.05),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),

          child: Row(
            children: [
              // Icon with gradient
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: gradient,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: gradientColors.first.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(
                  LucideIcons.bookOpen,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 16),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      roadmap.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    if (roadmap.targetRole != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            LucideIcons.target,
                            size: 11,
                            color: gradientColors.first,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              roadmap.targetRole!,
                              style: TextStyle(
                                color: gradientColors.first,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          '$progressPercent% done',
                          style: TextStyle(
                            color: progress >= 1.0
                                ? AppColors.success
                                : AppColors.textSecondaryLight,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          '•',
                          style: TextStyle(
                            color: AppColors.textSecondaryLight,
                            fontSize: 10,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$completed/$total',
                          style: const TextStyle(
                            color: AppColors.textSecondaryLight,
                            fontSize: 11,
                          ),
                        ),
                        if (roadmap.skillGaps.isNotEmpty) ...[
                          const SizedBox(width: 4),
                          const Text(
                            '•',
                            style: TextStyle(
                              color: AppColors.textSecondaryLight,
                              fontSize: 10,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${roadmap.skillGaps.length} gaps',
                            style: const TextStyle(
                              color: AppColors.warning,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor: isDark
                            ? AppColors.surfaceDark2
                            : Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          progress >= 1.0
                              ? AppColors.success
                              : gradientColors.first,
                        ),
                        minHeight: 5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // Arrow
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.surfaceDark2
                      : gradientColors.first.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  LucideIcons.arrowRight,
                  size: 16,
                  color: gradientColors.first,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
