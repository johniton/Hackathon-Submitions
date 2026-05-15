import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:hustlr/core/theme/app_colors.dart';
import 'package:hustlr/core/widgets/glass_card.dart';

class AiGeneratePage extends StatefulWidget {
  const AiGeneratePage({super.key});
  @override
  State<AiGeneratePage> createState() => _AiGeneratePageState();
}

class _AiGeneratePageState extends State<AiGeneratePage> {
  int _source = 0; // 0=roadmap, 1=pdf, 2=youtube, 3=paste
  int _cardCount = 15;
  int _difficulty = 1; // 0=beginner, 1=intermediate, 2=advanced
  final _selectedTypes = <int>{0, 2}; // QA, T/F selected by default
  bool _generating = false;
  bool _generated = false;
  final _urlCtrl = TextEditingController();
  final _pasteCtrl = TextEditingController();
  String _selectedTopic = 'Flutter Widgets';

  @override
  void dispose() { _urlCtrl.dispose(); _pasteCtrl.dispose(); super.dispose(); }

  void _generate() async {
    setState(() => _generating = true);
    await Future.delayed(const Duration(seconds: 2));
    setState(() { _generating = false; _generated = true; });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (_generating) return _loadingView(context, isDark);
    if (_generated) return _previewView(context, isDark);

    return Scaffold(
      appBar: AppBar(title: const Text('AI Flashcard Generator')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Source selection
          Text('Source', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Row(children: [
            _sourceBtn(0, '📋', 'Roadmap', isDark),
            const SizedBox(width: 8),
            _sourceBtn(1, '📄', 'PDF/Notes', isDark),
            const SizedBox(width: 8),
            _sourceBtn(2, '🎥', 'YouTube', isDark),
            const SizedBox(width: 8),
            _sourceBtn(3, '✍️', 'Paste', isDark),
          ]),
          const SizedBox(height: 16),

          // Source-specific input
          if (_source == 0) _roadmapInput(isDark),
          if (_source == 1) _pdfInput(isDark),
          if (_source == 2) _youtubeInput(isDark),
          if (_source == 3) _pasteInput(isDark),
          const SizedBox(height: 24),

          // Card count
          Text('Number of Cards', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Row(children: [
            Text('$_cardCount', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: AppColors.primary)),
            const SizedBox(width: 4),
            const Text('cards', style: TextStyle(color: AppColors.textSecondaryLight, fontSize: 13)),
          ]),
          Slider(
            value: _cardCount.toDouble(), min: 5, max: 50, divisions: 9,
            activeColor: AppColors.primary,
            onChanged: (v) => setState(() => _cardCount = v.toInt()),
          ),
          const SizedBox(height: 20),

          // Question types
          Text('Question Types', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            _typeToggle(0, 'Q & A', LucideIcons.helpCircle, isDark),
            _typeToggle(1, 'Fill-in-Blank', LucideIcons.edit3, isDark),
            _typeToggle(2, 'True / False', LucideIcons.checkSquare, isDark),
            _typeToggle(3, 'Code Output', LucideIcons.code, isDark),
          ]),
          const SizedBox(height: 24),

          // Difficulty
          Text('Difficulty', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          Row(children: [
            _diffBtn(0, 'Beginner', AppColors.success, isDark),
            const SizedBox(width: 8),
            _diffBtn(1, 'Intermediate', AppColors.warning, isDark),
            const SizedBox(width: 8),
            _diffBtn(2, 'Advanced', AppColors.error, isDark),
          ]),
          const SizedBox(height: 32),

          // Generate button
          GestureDetector(
            onTap: _generate,
            child: Container(
              width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 6))]),
              child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(LucideIcons.sparkles, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text('Generate Flashcards', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              ]),
            ),
          ),
          const SizedBox(height: 40),
        ]),
      ),
    );
  }

  Widget _sourceBtn(int idx, String emoji, String label, bool isDark) {
    final sel = _source == idx;
    return Expanded(child: GestureDetector(
      onTap: () => setState(() => _source = idx),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200), padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: sel ? AppColors.primaryGradient : null,
          color: sel ? null : (isDark ? AppColors.surfaceDark : Colors.white),
          borderRadius: BorderRadius.circular(14),
          border: sel ? null : Border.all(color: isDark ? Colors.white10 : Colors.black12),
        ),
        child: Column(children: [
          Text(emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(height: 6),
          Text(label, style: TextStyle(color: sel ? Colors.white : AppColors.textSecondaryLight, fontSize: 11, fontWeight: FontWeight.w600)),
        ]),
      ),
    ));
  }

  Widget _roadmapInput(bool isDark) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: isDark ? AppColors.surfaceDark : Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: isDark ? Colors.white10 : Colors.black12)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Select Roadmap Topic', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
      const SizedBox(height: 10),
      Wrap(spacing: 8, runSpacing: 8, children: ['Flutter Widgets', 'Dart Basics', 'State Management', 'Navigation', 'Networking'].map((t) {
        final sel = _selectedTopic == t;
        return GestureDetector(
          onTap: () => setState(() => _selectedTopic = t),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(color: sel ? AppColors.primary : (isDark ? AppColors.surfaceDark2 : Colors.grey.shade100), borderRadius: BorderRadius.circular(8)),
            child: Text(t, style: TextStyle(color: sel ? Colors.white : AppColors.textSecondaryLight, fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        );
      }).toList()),
    ]),
  );

  Widget _pdfInput(bool isDark) => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: isDark ? AppColors.surfaceDark : Colors.white, borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.primary.withValues(alpha: 0.3), style: BorderStyle.solid),
    ),
    child: const Column(children: [
      Icon(LucideIcons.upload, color: AppColors.primary, size: 36),
      SizedBox(height: 10),
      Text('Upload PDF or Notes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      SizedBox(height: 4),
      Text('Tap to browse files', style: TextStyle(color: AppColors.textSecondaryLight, fontSize: 12)),
    ]),
  );

  Widget _youtubeInput(bool isDark) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: isDark ? AppColors.surfaceDark : Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: isDark ? Colors.white10 : Colors.black12)),
    child: Row(children: [
      const Icon(LucideIcons.play, color: AppColors.error, size: 20),
      const SizedBox(width: 10),
      Expanded(child: TextField(controller: _urlCtrl, decoration: const InputDecoration(border: InputBorder.none, hintText: 'Paste YouTube URL...', hintStyle: TextStyle(color: AppColors.textSecondaryLight, fontSize: 14)))),
    ]),
  );

  Widget _pasteInput(bool isDark) => Container(
    decoration: BoxDecoration(color: isDark ? AppColors.surfaceDark : Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: isDark ? Colors.white10 : Colors.black12)),
    child: TextField(controller: _pasteCtrl, maxLines: 6, decoration: const InputDecoration(border: InputBorder.none, contentPadding: EdgeInsets.all(16), hintText: 'Paste your notes or content here...', hintStyle: TextStyle(color: AppColors.textSecondaryLight, fontSize: 14))),
  );

  Widget _typeToggle(int idx, String label, IconData icon, bool isDark) {
    final sel = _selectedTypes.contains(idx);
    return GestureDetector(
      onTap: () => setState(() => sel ? _selectedTypes.remove(idx) : _selectedTypes.add(idx)),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          gradient: sel ? AppColors.primaryGradient : null,
          color: sel ? null : (isDark ? AppColors.surfaceDark : Colors.white),
          borderRadius: BorderRadius.circular(10),
          border: sel ? null : Border.all(color: isDark ? Colors.white10 : Colors.black12),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: sel ? Colors.white : AppColors.textSecondaryLight),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: sel ? Colors.white : AppColors.textSecondaryLight, fontSize: 12, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }

  Widget _diffBtn(int idx, String label, Color color, bool isDark) {
    final sel = _difficulty == idx;
    return Expanded(child: GestureDetector(
      onTap: () => setState(() => _difficulty = idx),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: sel ? color : (isDark ? AppColors.surfaceDark : Colors.white),
          borderRadius: BorderRadius.circular(10),
          border: sel ? null : Border.all(color: isDark ? Colors.white10 : Colors.black12),
        ),
        child: Center(child: Text(label, style: TextStyle(color: sel ? Colors.white : AppColors.textSecondaryLight, fontSize: 12, fontWeight: FontWeight.w600))),
      ),
    ));
  }

  Widget _loadingView(BuildContext context, bool isDark) {
    return Scaffold(
      appBar: AppBar(title: const Text('Generating...')),
      body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(width: 60, height: 60, child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 4)),
        const SizedBox(height: 24),
        const Text('AI is generating your flashcards...', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 8),
        Text('Creating $_cardCount cards from $_selectedTopic', style: const TextStyle(color: AppColors.textSecondaryLight, fontSize: 13)),
      ])),
    );
  }

  Widget _previewView(BuildContext context, bool isDark) {
    return Scaffold(
      appBar: AppBar(title: const Text('Preview Cards')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: GlassCard(padding: const EdgeInsets.all(14), borderRadius: 12, child: Row(children: [
            const Icon(LucideIcons.sparkles, color: AppColors.primary, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('$_cardCount cards generated!', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const Text('Review and save to your deck', style: TextStyle(color: AppColors.textSecondaryLight, fontSize: 12)),
            ])),
          ])),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: 5, separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final qs = ['What is a Widget in Flutter?', 'The ____ method triggers a rebuild.', 'True or False: Dart is single-threaded.', 'What does this output: print(1 + 2);', 'Explain hot reload vs hot restart.'];
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: isDark ? AppColors.surfaceDark : Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06))),
                child: Row(children: [
                  Container(width: 28, height: 28, decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(7)),
                    child: Center(child: Text('${i + 1}', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12)))),
                  const SizedBox(width: 12),
                  Expanded(child: Text(qs[i], style: const TextStyle(fontSize: 13))),
                  const Icon(LucideIcons.edit3, size: 16, color: AppColors.textSecondaryLight),
                ]),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(20),
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(14)),
              child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(LucideIcons.save, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text('Save Deck  +50 XP', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}
