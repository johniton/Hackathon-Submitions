import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hustlr/core/theme/app_colors.dart';
import 'package:hustlr/core/services/session_service.dart';

class CompanyCreateJobPage extends StatefulWidget {
  const CompanyCreateJobPage({super.key});

  @override
  State<CompanyCreateJobPage> createState() => _CompanyCreateJobPageState();
}

class _CompanyCreateJobPageState extends State<CompanyCreateJobPage> {
  final _db = Supabase.instance.client;
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _salaryCtrl = TextEditingController();
  final _skillsCtrl = TextEditingController();
  final _topicsCtrl = TextEditingController();
  final _customQCtrl = TextEditingController();

  String _jobType = 'Full-Time';
  String _experienceLevel = 'Mid';
  bool _aiEnabled = false;
  int _aiThreshold = 60;
  String _aiInterviewType = 'TECHNICAL';
  String _aiDifficulty = 'MID';
  List<String> _customQuestions = [];
  bool _isSaving = false;

  final _jobTypes = ['Full-Time', 'Part-Time', 'Contract', 'Internship'];
  final _expLevels = ['Junior', 'Mid', 'Senior'];

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _locationCtrl.dispose();
    _salaryCtrl.dispose();
    _skillsCtrl.dispose();
    _topicsCtrl.dispose();
    _customQCtrl.dispose();
    super.dispose();
  }

  Future<void> _save(bool publish) async {
    if (_titleCtrl.text.trim().isEmpty || _descCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Title and description are required')));
      return;
    }
    setState(() => _isSaving = true);
    try {
      final companyId = await SessionService.getId();
      final skills = _skillsCtrl.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

      await _db.from('job_listings').insert({
        'company_id': companyId,
        'title': _titleCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'location': _locationCtrl.text.trim().isEmpty ? null : _locationCtrl.text.trim(),
        'job_type': _jobType,
        'salary_range': _salaryCtrl.text.trim().isEmpty ? null : _salaryCtrl.text.trim(),
        'required_skills': skills,
        'experience_level': _experienceLevel,
        'is_published': publish,
        'ai_screening_enabled': _aiEnabled,
        'ai_score_threshold': _aiThreshold,
        'ai_interview_topics': _topicsCtrl.text.trim().isEmpty ? null : _topicsCtrl.text.trim(),
        'ai_custom_questions': _customQuestions.isEmpty ? null : _customQuestions,
        'ai_interview_type': _aiInterviewType,
        'ai_difficulty': _aiDifficulty,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(publish ? 'Job published!' : 'Job saved as draft')));
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _section('JOB DETAILS'),
                    const SizedBox(height: 12),
                    _field(_titleCtrl, 'Job Title *', LucideIcons.briefcase),
                    const SizedBox(height: 12),
                    _multilineField(_descCtrl, 'Job Description *', LucideIcons.fileText, 5),
                    const SizedBox(height: 12),
                    _field(_locationCtrl, 'Location (e.g. Remote, Bangalore)', LucideIcons.mapPin),
                    const SizedBox(height: 12),
                    _field(_salaryCtrl, 'Salary Range (e.g. ₹12-18 LPA)', LucideIcons.indianRupee),
                    const SizedBox(height: 12),
                    _field(_skillsCtrl, 'Required Skills (comma separated)', LucideIcons.code2),
                    const SizedBox(height: 20),

                    _section('JOB TYPE'),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8, runSpacing: 8,
                      children: _jobTypes.map((t) => _chip(t, _jobType == t, () => setState(() => _jobType = t))).toList(),
                    ),
                    const SizedBox(height: 20),

                    _section('EXPERIENCE LEVEL'),
                    const SizedBox(height: 10),
                    Row(
                      children: _expLevels.map((e) => Expanded(child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: _chip(e, _experienceLevel == e, () => setState(() => _experienceLevel = e)),
                      ))).toList(),
                    ),
                    const SizedBox(height: 24),

                    // AI Screening Section
                    _buildAiSection(),

                    const SizedBox(height: 32),
                    Row(
                      children: [
                        Expanded(child: _btn('Save Draft', false, Colors.white24)),
                        const SizedBox(width: 12),
                        Expanded(child: _btn('Publish Job', true, AppColors.primary)),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08)))),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 38, height: 38,
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(10)),
              child: const Icon(LucideIcons.arrowLeft, color: Colors.white70, size: 18),
            ),
          ),
          const SizedBox(width: 14),
          const Text('Post a Job', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildAiSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _aiEnabled ? AppColors.primary.withValues(alpha: 0.06) : Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _aiEnabled ? AppColors.primary.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.bot, color: _aiEnabled ? AppColors.primary : Colors.white38, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('AI Screening Interview', style: TextStyle(color: _aiEnabled ? Colors.white : Colors.white54, fontSize: 15, fontWeight: FontWeight.bold)),
                  Text('Candidates take an AI interview before you see them', style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 12)),
                ]),
              ),
              Switch(
                value: _aiEnabled,
                onChanged: (v) => setState(() => _aiEnabled = v),
                activeColor: AppColors.primary,
              ),
            ],
          ),
          if (_aiEnabled) ...[
            const SizedBox(height: 20),
            _section('MINIMUM PASS SCORE: ${_aiThreshold.round()}'),
            const SizedBox(height: 8),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: AppColors.primary,
                thumbColor: AppColors.primary,
                inactiveTrackColor: Colors.white.withValues(alpha: 0.1),
              ),
              child: Slider(
                value: _aiThreshold.toDouble(),
                min: 0, max: 100, divisions: 10,
                onChanged: (v) => setState(() => _aiThreshold = v.round()),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Lenient (0)', style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 11)),
                Text('Strict (100)', style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 11)),
              ],
            ),
            const SizedBox(height: 20),

            _section('INTERVIEW TYPE'),
            const SizedBox(height: 8),
            Row(
              children: [
                _typeChip('TECHNICAL', 'Technical'),
                const SizedBox(width: 8),
                _typeChip('HR', 'HR'),
                const SizedBox(width: 8),
                _typeChip('MIXED', 'Mixed'),
              ],
            ),
            const SizedBox(height: 16),

            _section('DIFFICULTY'),
            const SizedBox(height: 8),
            Row(
              children: [
                _diffChip('JUNIOR', 'Junior'),
                const SizedBox(width: 8),
                _diffChip('MID', 'Mid'),
                const SizedBox(width: 8),
                _diffChip('SENIOR', 'Senior'),
              ],
            ),
            const SizedBox(height: 20),

            _section('SCREENING CONTEXT & TOPICS'),
            const SizedBox(height: 4),
            Text('Tell the AI what to focus on (topics, skills, culture, etc.)', style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 12)),
            const SizedBox(height: 8),
            _multilineField(_topicsCtrl, 'e.g. Focus on React, Node.js, system design, and problem solving under pressure. Also ask about remote work experience.', LucideIcons.messageSquare, 4),
            const SizedBox(height: 20),

            _section('CUSTOM QUESTIONS'),
            const SizedBox(height: 4),
            Text('Add specific questions you want asked', style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 12)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _field(_customQCtrl, 'Add a custom question', LucideIcons.plus)),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    final q = _customQCtrl.text.trim();
                    if (q.isNotEmpty) {
                      setState(() { _customQuestions.add(q); _customQCtrl.clear(); });
                    }
                  },
                  child: Container(
                    width: 44, height: 50,
                    decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(12)),
                    child: const Icon(LucideIcons.plus, color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
            if (_customQuestions.isNotEmpty) ...[
              const SizedBox(height: 10),
              ..._customQuestions.asMap().entries.map((e) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.04), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white.withValues(alpha: 0.08))),
                child: Row(
                  children: [
                    Text('${e.key + 1}.', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(e.value, style: const TextStyle(color: Colors.white70, fontSize: 13))),
                    GestureDetector(
                      onTap: () => setState(() => _customQuestions.removeAt(e.key)),
                      child: const Icon(LucideIcons.x, color: Colors.white38, size: 16),
                    ),
                  ],
                ),
              )),
            ],
          ],
        ],
      ),
    );
  }

  Widget _section(String text) {
    return Text(text, style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.5));
  }

  Widget _field(TextEditingController ctrl, String hint, IconData icon) {
    return Container(
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withValues(alpha: 0.08))),
      child: TextField(
        controller: ctrl,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: Colors.white38, size: 18),
          hintText: hint,
          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.25), fontSize: 13),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  Widget _multilineField(TextEditingController ctrl, String hint, IconData icon, int lines) {
    return Container(
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withValues(alpha: 0.08))),
      child: TextField(
        controller: ctrl,
        maxLines: lines,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          prefixIcon: Padding(padding: const EdgeInsets.only(top: 12), child: Icon(icon, color: Colors.white38, size: 18)),
          prefixIconConstraints: const BoxConstraints(minWidth: 48),
          hintText: hint,
          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.25), fontSize: 13),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  Widget _chip(String label, bool sel, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          gradient: sel ? AppColors.primaryGradient : null,
          color: sel ? null : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: sel ? Colors.transparent : Colors.white.withValues(alpha: 0.1)),
        ),
        child: Text(label, style: TextStyle(color: sel ? Colors.white : Colors.white54, fontSize: 13, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _typeChip(String value, String label) {
    final sel = _aiInterviewType == value;
    return Expanded(child: GestureDetector(
      onTap: () => setState(() => _aiInterviewType = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          gradient: sel ? AppColors.primaryGradient : null,
          color: sel ? null : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: sel ? Colors.transparent : Colors.white.withValues(alpha: 0.1)),
        ),
        child: Center(child: Text(label, style: TextStyle(color: sel ? Colors.white : Colors.white38, fontSize: 12, fontWeight: FontWeight.w600))),
      ),
    ));
  }

  Widget _diffChip(String value, String label) {
    final sel = _aiDifficulty == value;
    return Expanded(child: GestureDetector(
      onTap: () => setState(() => _aiDifficulty = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          gradient: sel ? AppColors.tealGradient : null,
          color: sel ? null : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: sel ? Colors.transparent : Colors.white.withValues(alpha: 0.1)),
        ),
        child: Center(child: Text(label, style: TextStyle(color: sel ? Colors.white : Colors.white38, fontSize: 12, fontWeight: FontWeight.w600))),
      ),
    ));
  }

  Widget _btn(String label, bool publish, Color color) {
    return GestureDetector(
      onTap: _isSaving ? null : () => _save(publish),
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          gradient: publish ? AppColors.primaryGradient : null,
          color: publish ? null : Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Center(
          child: _isSaving && publish
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(label, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }
}
