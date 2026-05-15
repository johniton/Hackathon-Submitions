import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:hustlr/core/theme/app_colors.dart';
import 'package:hustlr/core/widgets/glass_card.dart';

class CreatePostPage extends StatefulWidget {
  const CreatePostPage({super.key});
  @override
  State<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends State<CreatePostPage> {
  int _selectedType = 0;
  final _contentController = TextEditingController();
  final _types = ['🚀 Project', '🏆 Achievement', '❓ Question', '📚 Resource', '💼 Hiring'];
  final _typeIcons = [LucideIcons.rocket, LucideIcons.trophy, LucideIcons.helpCircle, LucideIcons.bookOpen, LucideIcons.briefcase];
  final _typeColors = [AppColors.primary, AppColors.warning, AppColors.info, AppColors.accent, AppColors.accentPurple];
  final _selectedTags = <String>{};
  final _allTags = ['Flutter', 'React', 'Node.js', 'Python', 'DSA', 'System Design', 'DevOps', 'ML', 'Firebase', 'AWS'];

  @override
  void dispose() { _contentController.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Post'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: GestureDetector(
              onTap: () { Navigator.pop(context); },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(20)),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(LucideIcons.send, color: Colors.white, size: 14),
                  SizedBox(width: 6),
                  Text('Post', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                ]),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Post type selector
          Text('Post Type', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          SizedBox(
            height: 80,
            child: ListView.separated(
              scrollDirection: Axis.horizontal, itemCount: _types.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, i) {
                final sel = _selectedType == i;
                return GestureDetector(
                  onTap: () => setState(() => _selectedType = i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200), width: 80,
                    decoration: BoxDecoration(
                      gradient: sel ? LinearGradient(colors: [_typeColors[i], _typeColors[i].withValues(alpha: 0.7)]) : null,
                      color: sel ? null : (isDark ? AppColors.surfaceDark : Colors.white),
                      borderRadius: BorderRadius.circular(14),
                      border: sel ? null : Border.all(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.08)),
                    ),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(_typeIcons[i], color: sel ? Colors.white : _typeColors[i], size: 24),
                      const SizedBox(height: 6),
                      Text(_types[i].split(' ').last, style: TextStyle(color: sel ? Colors.white : AppColors.textSecondaryLight, fontSize: 11, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 24),

          // Content
          Text('Content', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDark : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.08)),
            ),
            child: TextField(
              controller: _contentController, maxLines: 6,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Share your thoughts, projects, or questions...', border: InputBorder.none,
                contentPadding: const EdgeInsets.all(16),
                hintStyle: TextStyle(color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('${_contentController.text.length}/500', style: const TextStyle(color: AppColors.textSecondaryLight, fontSize: 11)),
            ),
          ),
          const SizedBox(height: 20),

          // Tags
          Text('Tags', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: _allTags.map((tag) {
            final sel = _selectedTags.contains(tag);
            return GestureDetector(
              onTap: () => setState(() => sel ? _selectedTags.remove(tag) : _selectedTags.add(tag)),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  gradient: sel ? AppColors.primaryGradient : null,
                  color: sel ? null : (isDark ? AppColors.surfaceDark : Colors.white),
                  borderRadius: BorderRadius.circular(20),
                  border: sel ? null : Border.all(color: isDark ? Colors.white10 : Colors.black12),
                ),
                child: Text('#$tag', style: TextStyle(color: sel ? Colors.white : AppColors.textSecondaryLight, fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            );
          }).toList()),
          const SizedBox(height: 24),

          // XP preview
          GlassCard(
            padding: const EdgeInsets.all(14), borderRadius: 12,
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                child: const Icon(LucideIcons.zap, color: AppColors.warning, size: 18),
              ),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Post Reward', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                Text('+${[50, 75, 30, 40, 60][_selectedType]} XP for posting', style: const TextStyle(color: AppColors.textSecondaryLight, fontSize: 12)),
              ]),
            ]),
          ),
          const SizedBox(height: 80),
        ]),
      ),
    );
  }
}
