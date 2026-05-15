/// Resume Builder — Step 2: GitHub Repo Picker
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:hustlr/core/theme/app_colors.dart';
import 'package:hustlr/features/resume_builder/data/resume_models.dart';
import 'package:hustlr/features/resume_builder/data/resume_service.dart';
import 'package:hustlr/features/resume_builder/presentation/pages/resume_details_page.dart';

class ResumeGithubPickerPage extends StatefulWidget {
  final ResumeFlowData flowData;
  const ResumeGithubPickerPage({super.key, required this.flowData});
  @override
  State<ResumeGithubPickerPage> createState() => _ResumeGithubPickerPageState();
}

class _ResumeGithubPickerPageState extends State<ResumeGithubPickerPage> {
  List<GithubRepo> _repos = [];
  bool _loading = true;
  String _error = '';
  String _search = '';

  @override
  void initState() {
    super.initState();
    _loadRepos();
  }

  Future<void> _loadRepos() async {
    try {
      final result = await ResumeService.fetchGithubData(
        widget.flowData.githubUrl,
        token: widget.flowData.githubToken.isNotEmpty ? widget.flowData.githubToken : null,
      );
      final repos = result['repos'] as List<GithubRepo>;
      widget.flowData.githubProfile = result['profile'] as Map<String, dynamic>?;
      setState(() { _repos = repos; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  int get _selectedCount => _repos.where((r) => r.selected).length;

  List<GithubRepo> get _filtered {
    if (_search.isEmpty) return _repos;
    final q = _search.toLowerCase();
    return _repos.where((r) =>
      r.name.toLowerCase().contains(q) ||
      r.language.toLowerCase().contains(q) ||
      r.description.toLowerCase().contains(q)
    ).toList();
  }

  void _continue() {
    widget.flowData.selectedRepos = _repos.where((r) => r.selected).toList();
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => ResumeDetailsPage(flowData: widget.flowData),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: Colors.transparent, elevation: 0,
        title: const Text('Select Repositories', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        centerTitle: true,
      ),
      body: Column(children: [
        // Progress
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _buildProgress(2, 5),
        ),
        const SizedBox(height: 12),

        // Search
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: TextField(
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Search repos...',
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.25)),
              prefixIcon: Icon(LucideIcons.search, color: Colors.white.withValues(alpha: 0.3), size: 18),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.05),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onChanged: (v) => setState(() => _search = v),
          ),
        ),
        const SizedBox(height: 8),

        // Select all / Clear
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(children: [
            GestureDetector(
              onTap: () => setState(() { for (final r in _repos) r.selected = true; }),
              child: Text('Select All', style: TextStyle(color: AppColors.primaryLight, fontSize: 12, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(width: 16),
            GestureDetector(
              onTap: () => setState(() { for (final r in _repos) r.selected = false; }),
              child: Text('Clear', style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12, fontWeight: FontWeight.w600)),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: AppColors.primaryLight.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
              child: Text('$_selectedCount selected', style: TextStyle(color: AppColors.primaryLight, fontSize: 12, fontWeight: FontWeight.w700)),
            ),
          ]),
        ),
        const SizedBox(height: 8),

        // Repo list
        Expanded(
          child: _loading
            ? const Center(child: CircularProgressIndicator(color: Colors.white))
            : _error.isNotEmpty
              ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error, style: const TextStyle(color: AppColors.error, fontSize: 13), textAlign: TextAlign.center)))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: _filtered.length,
                  itemBuilder: (_, i) => _repoTile(_filtered[i]),
                ),
        ),

        // Continue button
        Padding(
          padding: const EdgeInsets.all(20),
          child: GestureDetector(
            onTap: _continue,
            child: Container(
              height: 56, width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [AppColors.primaryLight, AppColors.primary]),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Text(
                  _selectedCount > 0 ? 'Continue — $_selectedCount Repos' : 'Skip — No Repos',
                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _repoTile(GithubRepo repo) {
    return GestureDetector(
      onTap: () => setState(() => repo.selected = !repo.selected),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: repo.selected ? AppColors.primaryLight.withValues(alpha: 0.08) : Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: repo.selected ? AppColors.primaryLight.withValues(alpha: 0.4) : Colors.white.withValues(alpha: 0.06)),
        ),
        child: Row(children: [
          Icon(
            repo.selected ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
            color: repo.selected ? AppColors.primaryLight : Colors.white.withValues(alpha: 0.3), size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(child: Text(repo.name, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis)),
              if (repo.isPrivate) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4)),
                  child: const Text('PRIVATE', style: TextStyle(color: Colors.orange, fontSize: 8, fontWeight: FontWeight.w800)),
                ),
              ],
            ]),
            if (repo.description.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(repo.description, style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
            const SizedBox(height: 4),
            Row(children: [
              if (repo.language.isNotEmpty) ...[
                Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: _langColor(repo.language))),
                const SizedBox(width: 4),
                Text(repo.language, style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11)),
                const SizedBox(width: 12),
              ],
              Icon(LucideIcons.star, size: 12, color: Colors.white.withValues(alpha: 0.3)),
              const SizedBox(width: 3),
              Text('${repo.stars}', style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 11)),
            ]),
          ])),
        ]),
      ),
    );
  }

  Color _langColor(String lang) {
    final colors = {
      'Python': Colors.blue, 'JavaScript': Colors.yellow, 'TypeScript': Colors.blue.shade300,
      'Dart': Colors.cyan, 'Java': Colors.red, 'Go': Colors.teal, 'Rust': Colors.deepOrange,
      'C++': Colors.pink, 'C': Colors.grey, 'Ruby': Colors.red.shade300, 'Swift': Colors.orange,
      'Kotlin': Colors.purple, 'HTML': Colors.orange.shade300, 'CSS': Colors.purple.shade200,
    };
    return colors[lang] ?? Colors.white.withValues(alpha: 0.4);
  }

  Widget _buildProgress(int current, int total) {
    return Column(children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: LinearProgressIndicator(
          value: current / total, minHeight: 4,
          backgroundColor: Colors.white.withValues(alpha: 0.08),
          valueColor: const AlwaysStoppedAnimation(AppColors.primaryLight),
        ),
      ),
      const SizedBox(height: 6),
      Text('STEP $current OF $total', style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.35), fontWeight: FontWeight.w700, letterSpacing: 2)),
    ]);
  }
}
