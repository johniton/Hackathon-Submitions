import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:hustlr/core/theme/app_colors.dart';
import 'package:hustlr/core/widgets/glass_card.dart';

class DeckSharePage extends StatelessWidget {
  const DeckSharePage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(title: const Text('Share & Export')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Deck info
          GlassCard(padding: const EdgeInsets.all(16), borderRadius: 14, child: Row(children: [
            Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
              child: const Icon(LucideIcons.layers, color: AppColors.primary, size: 24)),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Flutter Widgets', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const Text('48 cards · 92% mastery', style: TextStyle(color: AppColors.textSecondaryLight, fontSize: 13)),
            ])),
          ])),
          const SizedBox(height: 24),

          // Share to community
          Text('Share to Community', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: isDark ? AppColors.surfaceDark : Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('Make Public', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                Switch(value: true, onChanged: (_) {}, activeColor: AppColors.primary),
              ]),
              const SizedBox(height: 8),
              TextField(
                decoration: InputDecoration(hintText: 'Add a description...', hintStyle: TextStyle(color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight, fontSize: 14),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.black12)),
                  contentPadding: const EdgeInsets.all(12)),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              GestureDetector(
                child: Container(
                  width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(10)),
                  child: const Center(child: Text('Publish to Community', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14))),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 24),

          // Export options
          Text('Export & Share', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 14),
          _exportOption(LucideIcons.link, 'Copy Share Link', 'hustlr.app/deck/flutter-widgets', AppColors.primary, isDark),
          const SizedBox(height: 10),
          _exportOption(LucideIcons.messageCircle, 'Share via WhatsApp', 'Send deck link to contacts', AppColors.success, isDark),
          const SizedBox(height: 10),
          _exportOption(LucideIcons.send, 'Share via Telegram', 'Send deck link to groups', AppColors.info, isDark),
          const SizedBox(height: 10),
          _exportOption(LucideIcons.download, 'Export as PDF', 'Download printable flashcards', AppColors.accentOrange, isDark),
          const SizedBox(height: 24),

          // Stats
          Text('Deck Stats', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: _statCard('Clones', '142', AppColors.primary, isDark)),
            const SizedBox(width: 10),
            Expanded(child: _statCard('Rating', '4.8 ⭐', AppColors.warning, isDark)),
            const SizedBox(width: 10),
            Expanded(child: _statCard('Reviews', '28', AppColors.accent, isDark)),
          ]),
          const SizedBox(height: 24),

          // Import
          Text('Import Deck', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: isDark ? AppColors.surfaceDark : Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: isDark ? Colors.white10 : Colors.black12)),
            child: Row(children: [
              const Icon(LucideIcons.download, color: AppColors.accent, size: 20),
              const SizedBox(width: 12),
              Expanded(child: TextField(
                decoration: InputDecoration(border: InputBorder.none, hintText: 'Enter deck code or link...', hintStyle: TextStyle(color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight, fontSize: 14)),
              )),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                child: const Text('Import', style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ]),
          ),
          const SizedBox(height: 80),
        ]),
      ),
    );
  }

  Widget _exportOption(IconData icon, String title, String subtitle, Color color, bool isDark) {
    return GlassCard(
      padding: const EdgeInsets.all(14), borderRadius: 12,
      child: Row(children: [
        Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color, size: 18)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          Text(subtitle, style: const TextStyle(color: AppColors.textSecondaryLight, fontSize: 12)),
        ])),
        Icon(LucideIcons.chevronRight, size: 18, color: AppColors.textSecondaryLight),
      ]),
    );
  }

  Widget _statCard(String label, String value, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: isDark ? AppColors.surfaceDark : Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06))),
      child: Column(children: [
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: AppColors.textSecondaryLight, fontSize: 12)),
      ]),
    );
  }
}
