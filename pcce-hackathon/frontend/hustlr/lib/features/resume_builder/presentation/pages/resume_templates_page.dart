/// Resume Builder — Step 4: Template Picker + Generate
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:hustlr/core/theme/app_colors.dart';
import 'package:hustlr/features/resume_builder/data/resume_models.dart';
import 'package:hustlr/features/resume_builder/presentation/pages/resume_generating_page.dart';

class ResumeTemplatePicker extends StatefulWidget {
  final ResumeFlowData flowData;
  const ResumeTemplatePicker({super.key, required this.flowData});
  @override
  State<ResumeTemplatePicker> createState() => _ResumeTemplatePickerState();
}

class _ResumeTemplatePickerState extends State<ResumeTemplatePicker> {
  String _selected = 'ats_safe';

  final _templates = [
    _TemplateInfo('ats_safe', 'ATS-Safe', 'Maximum ATS compatibility. Clean two-column, Lato font, blue accents. Works everywhere.', LucideIcons.shieldCheck, Colors.green),
    _TemplateInfo('classic', 'Classic', 'Lato font, centered header, blue gradient accents. Traditional paper resume look. Best all-rounder.', LucideIcons.fileText, Colors.indigo),
    _TemplateInfo('executive', 'Executive', 'Merriweather serif, sidebar section labels, navy accents. Professional and authoritative.', LucideIcons.award, Colors.blueGrey),
    _TemplateInfo('creative', 'Creative', 'Merriweather serif with red accent. Professional and elegant. Great for mid-senior roles.', LucideIcons.palette, Colors.red),
    _TemplateInfo('academic', 'Academic', 'Libre Baskerville serif, education-first. Ideal for Research, PhD, and Teaching roles.', LucideIcons.graduationCap, Colors.blue),
    _TemplateInfo('fresher', 'Fresher', 'Dark gradient header, skills-first. Outfit font, modern tech look. Perfect for 0-2 years.', LucideIcons.rocket, Colors.orange),
    _TemplateInfo('minimal', 'Minimal', 'IBM Plex Sans, ultra-clean monochrome. Subtle dividers, maximum content density.', LucideIcons.minus, Colors.grey),
  ];

  void _generate() {
    widget.flowData.templateName = _selected;
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => ResumeGeneratingPage(flowData: widget.flowData),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: Colors.transparent, elevation: 0,
        title: const Text('Pick a Template', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          _buildProgress(4, 5),
          const SizedBox(height: 24),

          Expanded(child: ListView.builder(
            itemCount: _templates.length,
            itemBuilder: (_, i) {
              final t = _templates[i];
              final isSelected = _selected == t.id;
              return GestureDetector(
                onTap: () => setState(() => _selected = t.id),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: isSelected ? t.color.withValues(alpha: 0.08) : Colors.white.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected ? t.color.withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.06),
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(children: [
                    Container(
                      width: 48, height: 48,
                      decoration: BoxDecoration(
                        color: t.color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(t.icon, color: t.color, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(t.label, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 3),
                      Text(t.desc, style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 11, height: 1.4)),
                    ])),
                    const SizedBox(width: 8),
                    Icon(
                      isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                      color: isSelected ? t.color : Colors.white.withValues(alpha: 0.2), size: 22,
                    ),
                  ]),
                ),
              );
            },
          )),

          GestureDetector(
            onTap: _generate,
            child: Container(
              height: 56, width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [AppColors.primaryLight, AppColors.primary]),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(LucideIcons.sparkles, color: Colors.white, size: 20),
                SizedBox(width: 10),
                Text('Generate Resume', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
              ]),
            ),
          ),
          const SizedBox(height: 10),
        ]),
      ),
    );
  }

  Widget _buildProgress(int current, int total) {
    return Column(children: [
      ClipRRect(borderRadius: BorderRadius.circular(3), child: LinearProgressIndicator(
        value: current / total, minHeight: 4,
        backgroundColor: Colors.white.withValues(alpha: 0.08),
        valueColor: const AlwaysStoppedAnimation(AppColors.primaryLight),
      )),
      const SizedBox(height: 6),
      Text('STEP $current OF $total', style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.35), fontWeight: FontWeight.w700, letterSpacing: 2)),
    ]);
  }
}

class _TemplateInfo {
  final String id, label, desc;
  final IconData icon;
  final Color color;
  const _TemplateInfo(this.id, this.label, this.desc, this.icon, this.color);
}
