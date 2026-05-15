import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:hustlr/core/theme/app_colors.dart';
import 'package:hustlr/core/widgets/glass_card.dart';
import 'package:hustlr/core/widgets/gradient_card.dart';
import 'package:hustlr/core/widgets/primary_button.dart';
import 'package:hustlr/features/resume_builder/presentation/pages/resume_input_page.dart';

class ResumeBuilderDashboardPage extends StatelessWidget {
  const ResumeBuilderDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(title: const Text('Resume Builder')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero card
            GradientCard(
              gradient: AppColors.purpleGradient,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(LucideIcons.sparkles, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Smart Resume Builder', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                    SizedBox(height: 2),
                    Text('AI-Powered • ATS-Optimised', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  ])),
                ]),
                const SizedBox(height: 16),
                const Text(
                  'Import from GitHub & LinkedIn, tailor to any job description, get an ATS-friendly resume in seconds.',
                  style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ResumeInputPage())),
                  child: Container(
                    width: double.infinity, height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(LucideIcons.sparkles, color: Color(0xFF6C63FF), size: 18),
                      SizedBox(width: 8),
                      Text('Build New Resume', style: TextStyle(color: Color(0xFF6C63FF), fontSize: 14, fontWeight: FontWeight.w800)),
                    ]),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 24),

            // Features grid
            Text('How It Works', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            _featureRow(context, [
              _FeatureItem(LucideIcons.github, 'GitHub Import', 'Select repos, detect tech stack automatically', AppColors.textPrimaryLight),
              _FeatureItem(LucideIcons.linkedin, 'LinkedIn Import', 'Auto-fetch profile or enter details manually', const Color(0xFF0A66C2)),
            ], isDark),
            const SizedBox(height: 10),
            _featureRow(context, [
              _FeatureItem(LucideIcons.briefcase, 'JD Matching', 'Tailor resume to specific job descriptions', AppColors.accentOrange),
              _FeatureItem(LucideIcons.award, 'Certificate OCR', 'Upload certs, AI extracts details automatically', AppColors.accent),
            ], isDark),
            const SizedBox(height: 10),
            _featureRow(context, [
              _FeatureItem(LucideIcons.shieldCheck, 'ATS Scoring', 'Real-time ATS compatibility scoring', Colors.green),
              _FeatureItem(LucideIcons.fileDown, 'Export', 'Download as PDF or DOCX instantly', AppColors.primary),
            ], isDark),

            const SizedBox(height: 24),

            // Templates preview
            Text('Templates', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            SizedBox(
              height: 140,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _templateCard('ATS-Safe', Colors.green, LucideIcons.shieldCheck),
                  _templateCard('Creative', Colors.purple, LucideIcons.palette),
                  _templateCard('Academic', Colors.blue, LucideIcons.graduationCap),
                  _templateCard('Fresher', Colors.orange, LucideIcons.rocket),
                ],
              ),
            ),

            const SizedBox(height: 28),
            PrimaryButton(
              text: 'Start Building →',
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ResumeInputPage())),
              icon: LucideIcons.arrowRight,
            ),
          ],
        ),
      ),
    );
  }

  Widget _featureRow(BuildContext context, List<_FeatureItem> items, bool isDark) {
    return Row(children: items.map((item) {
      return Expanded(child: Padding(
        padding: EdgeInsets.only(right: item == items.last ? 0 : 10),
        child: GlassCard(
          padding: const EdgeInsets.all(14),
          borderRadius: 12,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: item.color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
              child: Icon(item.icon, color: item.color, size: 18),
            ),
            const SizedBox(height: 10),
            Text(item.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
            const SizedBox(height: 3),
            Text(item.subtitle, style: TextStyle(fontSize: 10, color: isDark ? Colors.white38 : Colors.black45, height: 1.3)),
          ]),
        ),
      ));
    }).toList());
  }

  Widget _templateCard(String name, Color color, IconData icon) {
    return Container(
      width: 110,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [color.withValues(alpha: 0.8), color]),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white70, size: 26),
          const Spacer(),
          Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }
}

class _FeatureItem {
  final IconData icon;
  final String title, subtitle;
  final Color color;
  const _FeatureItem(this.icon, this.title, this.subtitle, this.color);
}
