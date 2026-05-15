import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:hustlr/core/theme/app_colors.dart';
import 'package:hustlr/features/flashcards/data/ai_flashcard_service.dart';
import 'package:hustlr/features/learn_skills/data/practical_project_service.dart';

class PracticalProjectsPage extends StatefulWidget {
  final PracticalProjectPack pack;
  final String skillLabel;

  const PracticalProjectsPage({
    super.key,
    required this.pack,
    required this.skillLabel,
  });

  @override
  State<PracticalProjectsPage> createState() => _PracticalProjectsPageState();
}

class _PracticalProjectsPageState extends State<PracticalProjectsPage> {

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final pack = widget.pack;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Practical Work'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.18),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          LucideIcons.briefcase,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.skillLabel,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Role-play the work. Build like you are already on the job.',
                              style: TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Generated from your roadmap topics and current level.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ...pack.projects.map(
              (project) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
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
                          Expanded(
                            child: Text(
                              project.title,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const Icon(LucideIcons.sparkles, size: 16, color: AppColors.primary),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        project.rolePlayContext,
                        style: const TextStyle(
                          color: AppColors.textSecondaryLight,
                          fontSize: 12,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _sectionTitle('Why this matters'),
                      const SizedBox(height: 6),
                      Text(
                        project.whyItMatters,
                        style: const TextStyle(fontSize: 12, height: 1.5),
                      ),
                      const SizedBox(height: 12),
                      _sectionTitle('Deliverables'),
                      const SizedBox(height: 6),
                      ...project.deliverables.map(
                        (item) => _bulletRow(item),
                      ),
                      const SizedBox(height: 12),
                      _sectionTitle('Starter steps'),
                      const SizedBox(height: 6),
                      ...project.starterSteps.map(
                        (item) => _bulletRow(item),
                      ),
                      if (project.skills.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _sectionTitle('Skills reinforced'),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: project.skills
                              .map(
                                (skill) => Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    skill,
                                    style: const TextStyle(
                                      color: AppColors.primary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _onSubmitProject(context, project),
                              icon: const Icon(LucideIcons.uploadCloud, size: 16),
                              label: const Text('Submit'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onSubmitProject(BuildContext context, PracticalProject project) async {
    final controller = TextEditingController();
    final link = await showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Submit GitHub repo'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'https://github.com/owner/repo'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, null), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: const Text('Submit')),
        ],
      ),
    );

    if (link == null || link.isEmpty) return;

    // show loading
    showDialog<void>(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
    int rating;
    try {
      rating = await PracticalProjectService.reviewGitHubRepo(link, project);
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Review failed: $e')));
      return;
    }

    Navigator.pop(context);

    // show rating dialog
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Project Rating'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$rating/10',
              style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: AppColors.primary),
            ),
            const SizedBox(height: 12),
            Text(
              _getRatingMessage(rating),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: AppColors.textSecondaryLight),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  String _getRatingMessage(int rating) {
    if (rating >= 9) return 'Excellent submission! Meets all deliverables.';
    if (rating >= 7) return 'Good work! Most deliverables are complete.';
    if (rating >= 5) return 'Fair submission. Some deliverables need attention.';
    if (rating >= 3) return 'Needs improvement. Missing key deliverables.';
    return 'Incomplete. Significant work remaining.';
  }

  Widget _sectionTitle(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w800,
        color: AppColors.primary,
      ),
    );
  }

  Widget _bulletRow(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 5),
            child: Icon(LucideIcons.dot, size: 12, color: AppColors.textSecondaryLight),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 12, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}
