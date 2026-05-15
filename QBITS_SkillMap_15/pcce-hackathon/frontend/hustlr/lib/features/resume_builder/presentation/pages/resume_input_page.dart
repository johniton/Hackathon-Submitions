/// Resume Builder — Step 1: Profile Data Input
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:hustlr/core/theme/app_colors.dart';
import 'package:hustlr/features/resume_builder/data/resume_models.dart';
import 'package:hustlr/features/resume_builder/data/resume_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:hustlr/features/resume_builder/presentation/pages/resume_github_picker_page.dart';
class ResumeInputPage extends StatefulWidget {
  const ResumeInputPage({super.key});
  @override
  State<ResumeInputPage> createState() => _ResumeInputPageState();
}

class _ResumeInputPageState extends State<ResumeInputPage> {
  // Data source controllers
  final _githubCtrl = TextEditingController();
  final _tokenCtrl = TextEditingController();
  final _linkedinTextCtrl = TextEditingController();

  // Profile fields - always visible
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _headlineCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _summaryCtrl = TextEditingController();
  final _skillsCtrl = TextEditingController();

  // Experience entries
  final List<Map<String, TextEditingController>> _expEntries = [];

  // Education
  final _schoolCtrl = TextEditingController();
  final _degreeCtrl = TextEditingController();
  final _eduYearCtrl = TextEditingController();
  final _gpaCtrl = TextEditingController();

  bool _showToken = false;
  bool _ocrLoading = false;
  bool _dataImported = false;
  final List<CertificateInfo> _scannedCerts = [];

  final _flowData = ResumeFlowData();

  @override
  void initState() {
    super.initState();
    _addExpEntry(); // Start with one empty experience
  }

  void _addExpEntry() {
    _expEntries.add({
      'title': TextEditingController(),
      'company': TextEditingController(),
      'duration': TextEditingController(),
      'description': TextEditingController(),
    });
    setState(() {});
  }

  void _removeExpEntry(int index) {
    if (_expEntries.length > 1) {
      for (var ctrl in _expEntries[index].values) { ctrl.dispose(); }
      _expEntries.removeAt(index);
      setState(() {});
    }
  }

  /// Scan certificate using OCR
  Future<void> _scanCertificate() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg'],
      );

      if (result == null || result.files.single.path == null) return;

      setState(() => _ocrLoading = true);

      final certInfo = await ResumeService.ocrCertificate(
        result.files.single.path!,
        result.files.single.name,
      );

      setState(() {
        _ocrLoading = false;
        _dataImported = true;
        _scannedCerts.add(certInfo);
      });

      // Auto-fill extracted data
      if (certInfo.skills.isNotEmpty) {
        final existingSkills = _skillsCtrl.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
        for (var skill in certInfo.skills) {
          if (!existingSkills.contains(skill)) existingSkills.add(skill);
        }
        _skillsCtrl.text = existingSkills.join(', ');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ Scanned: ${certInfo.certName.isNotEmpty ? certInfo.certName : "Certificate"} — Added ${certInfo.skills.length} skills'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _ocrLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('OCR Failed: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  void _autoFillFromLinkedIn(LinkedInProfile p) {
    if (p.name.isNotEmpty && _nameCtrl.text.isEmpty) _nameCtrl.text = p.name;
    if (p.headline.isNotEmpty && _headlineCtrl.text.isEmpty) _headlineCtrl.text = p.headline;
    if (p.location.isNotEmpty && _locationCtrl.text.isEmpty) _locationCtrl.text = p.location;
    if (p.summary.isNotEmpty && _summaryCtrl.text.isEmpty) _summaryCtrl.text = p.summary;
    if (p.skills.isNotEmpty && _skillsCtrl.text.isEmpty) _skillsCtrl.text = p.skills.join(', ');

    // Fill education
    if (p.education.isNotEmpty) {
      final edu = p.education.first;
      if (_schoolCtrl.text.isEmpty) _schoolCtrl.text = edu['school'] ?? '';
      if (_degreeCtrl.text.isEmpty) _degreeCtrl.text = edu['degree'] ?? '';
      if (_eduYearCtrl.text.isEmpty) _eduYearCtrl.text = edu['year'] ?? edu['dates'] ?? '';
      if (_gpaCtrl.text.isEmpty) _gpaCtrl.text = edu['grade'] ?? edu['gpa'] ?? '';
    }

    // Fill experience
    if (p.experience.isNotEmpty) {
      // Clear the default empty entry
      for (var entry in _expEntries) { for (var ctrl in entry.values) { ctrl.dispose(); } }
      _expEntries.clear();
      for (var exp in p.experience) {
        _expEntries.add({
          'title': TextEditingController(text: exp['title'] ?? ''),
          'company': TextEditingController(text: exp['company'] ?? ''),
          'duration': TextEditingController(text: exp['duration'] ?? exp['dates'] ?? ''),
          'description': TextEditingController(text: exp['description'] ?? ''),
        });
      }
    }

    // Store LinkedIn profile for flow data
    _flowData.linkedinProfile = p;
  }

  bool get _hasMinimumData {
    return _nameCtrl.text.trim().isNotEmpty || _githubCtrl.text.trim().isNotEmpty;
  }

  void _continue() {
    // Build manual profile from all fields
    final experience = <Map<String, dynamic>>[];
    for (var entry in _expEntries) {
      final title = entry['title']!.text.trim();
      final company = entry['company']!.text.trim();
      if (title.isNotEmpty || company.isNotEmpty) {
        experience.add({
          'title': title,
          'company': company,
          'duration': entry['duration']!.text.trim(),
          'description': entry['description']!.text.trim(),
        });
      }
    }

    final education = <Map<String, dynamic>>[];
    if (_schoolCtrl.text.trim().isNotEmpty) {
      education.add({
        'school': _schoolCtrl.text.trim(),
        'degree': _degreeCtrl.text.trim(),
        'year': _eduYearCtrl.text.trim(),
        'grade': _gpaCtrl.text.trim(),
      });
    }

    _flowData.githubUrl = _githubCtrl.text.trim();
    _flowData.githubToken = _tokenCtrl.text.trim();
    _flowData.manualProfile = {
      'name': _nameCtrl.text.trim(),
      'email': _emailCtrl.text.trim(),
      'phone': _phoneCtrl.text.trim(),
      'headline': _headlineCtrl.text.trim(),
      'location': _locationCtrl.text.trim(),
      'summary': _summaryCtrl.text.trim(),
      'skills': _skillsCtrl.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList(),
      'experience': experience,
      'education': education,
      'certifications': _scannedCerts.map((c) => {
        'name': c.certName,
        'issuer': c.issuer,
        'date': c.issueDate,
      }).where((c) => c['name']!.toString().isNotEmpty).toList(),
    };

    Navigator.push(context, MaterialPageRoute(
      builder: (_) => ResumeGithubPickerPage(flowData: _flowData),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: Colors.transparent, elevation: 0,
        title: const Text('Smart Resume Builder', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _buildProgress(1, 5),
          const SizedBox(height: 20),

          // ── Quick Import Section ──
          _sectionTitle('Quick Import', LucideIcons.download),
          const SizedBox(height: 6),
          Text('Import from LinkedIn or GitHub to auto-fill your profile', style: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 11)),
          const SizedBox(height: 10),

          // GitHub URL
          Row(children: [
            Icon(LucideIcons.github, color: Colors.white38, size: 16),
            const SizedBox(width: 8),
            Expanded(child: _buildInput(_githubCtrl, 'github.com/username')),
          ]),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: () => setState(() => _showToken = !_showToken),
            child: Row(children: [
              const SizedBox(width: 24),
              Icon(_showToken ? LucideIcons.chevronDown : LucideIcons.chevronRight, color: Colors.white24, size: 14),
              const SizedBox(width: 4),
              Text('Private repos? Add PAT', style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 11)),
            ]),
          ),
          if (_showToken) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 24),
              child: _buildInput(_tokenCtrl, 'ghp_xxxxxxxxxxxxxxx', obscure: true),
            ),
          ],

          const SizedBox(height: 10),

          // Scan Certificate Button
          GestureDetector(
            onTap: _ocrLoading ? null : _scanCertificate,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
              ),
              child: Row(children: [
                _ocrLoading 
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryLight))
                  : const Icon(LucideIcons.fileSearch, color: AppColors.primaryLight, size: 16),
                const SizedBox(width: 8),
                Expanded(child: Text(_ocrLoading ? 'Scanning Document...' : 'Scan Certificate (OCR)', style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12))),
                const Icon(LucideIcons.upload, color: Colors.white24, size: 16),
              ]),
            ),
          ),
          
          if (_dataImported)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(children: [
                const Icon(LucideIcons.checkCircle, color: Colors.green, size: 14),
                const SizedBox(width: 6),
                Text('Data imported — review & edit below', style: TextStyle(color: Colors.green.withValues(alpha: 0.8), fontSize: 11, fontWeight: FontWeight.w600)),
              ]),
            ),

          const SizedBox(height: 24),
          Container(height: 1, color: Colors.white.withValues(alpha: 0.06)),
          const SizedBox(height: 20),

          // ── Personal Info ──
          _sectionTitle('Personal Information', LucideIcons.user),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _buildInput(_nameCtrl, 'Full Name *', icon: LucideIcons.user)),
            const SizedBox(width: 10),
            Expanded(child: _buildInput(_phoneCtrl, 'Phone', icon: LucideIcons.phone)),
          ]),
          const SizedBox(height: 10),
          _buildInput(_emailCtrl, 'Email', icon: LucideIcons.mail),
          const SizedBox(height: 10),
          _buildInput(_headlineCtrl, 'Professional Headline (e.g. Full-Stack Developer | AI Enthusiast)', icon: LucideIcons.briefcase),
          const SizedBox(height: 10),
          _buildInput(_locationCtrl, 'City, State, Country', icon: LucideIcons.mapPin),
          const SizedBox(height: 10),
          _buildInput(_summaryCtrl, 'Professional Summary — 2-3 sentences about you', maxLines: 3, icon: LucideIcons.fileText),

          const SizedBox(height: 20),

          // ── Skills ──
          _sectionTitle('Skills', LucideIcons.zap),
          const SizedBox(height: 8),
          _buildInput(_skillsCtrl, 'Python, JavaScript, React, Docker, Git... (comma separated)', icon: LucideIcons.code),

          const SizedBox(height: 20),

          // ── Experience ──
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            _sectionTitle('Experience', LucideIcons.briefcase),
            GestureDetector(
              onTap: _addExpEntry,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: AppColors.primaryLight.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(LucideIcons.plus, color: AppColors.primaryLight, size: 14),
                  const SizedBox(width: 4),
                  const Text('Add', style: TextStyle(color: AppColors.primaryLight, fontSize: 11, fontWeight: FontWeight.w700)),
                ]),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          ...List.generate(_expEntries.length, (i) => _buildExpCard(i)),

          const SizedBox(height: 20),

          // ── Education ──
          _sectionTitle('Education', LucideIcons.graduationCap),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _buildInput(_schoolCtrl, 'School / University', icon: LucideIcons.building)),
            const SizedBox(width: 10),
            Expanded(child: _buildInput(_eduYearCtrl, '2020 - 2024')),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _buildInput(_degreeCtrl, 'Degree (B.E. Computer Science)')),
            const SizedBox(width: 10),
            SizedBox(width: 100, child: _buildInput(_gpaCtrl, 'GPA/SGPA')),
          ]),

          const SizedBox(height: 32),

          // Continue button
          GestureDetector(
            onTap: _hasMinimumData ? _continue : null,
            child: Container(
              height: 56, width: double.infinity,
              decoration: BoxDecoration(
                gradient: _hasMinimumData ? LinearGradient(colors: [AppColors.primaryLight, AppColors.primary]) : null,
                color: _hasMinimumData ? null : Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(child: Text(
                'Continue — Select Repos',
                style: TextStyle(color: _hasMinimumData ? Colors.white : Colors.white38, fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: 0.5),
              )),
            ),
          ),
          const SizedBox(height: 24),
        ]),
      ),
    );
  }

  Widget _buildExpCard(int index) {
    final e = _expEntries[index];
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('Experience ${index + 1}', style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 10, fontWeight: FontWeight.w700)),
          const Spacer(),
          if (_expEntries.length > 1)
            GestureDetector(
              onTap: () => _removeExpEntry(index),
              child: Icon(LucideIcons.x, color: Colors.red.withValues(alpha: 0.5), size: 16),
            ),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: _buildInput(e['title']!, 'Job Title')),
          const SizedBox(width: 8),
          Expanded(child: _buildInput(e['company']!, 'Company')),
        ]),
        const SizedBox(height: 6),
        _buildInput(e['duration']!, 'Duration (e.g. Jan 2024 - Present)'),
        const SizedBox(height: 6),
        _buildInput(e['description']!, 'What did you do? Key responsibilities & achievements', maxLines: 3),
      ]),
    );
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

  Widget _sectionTitle(String title, IconData icon) {
    return Row(children: [
      Icon(icon, color: AppColors.primaryLight, size: 16),
      const SizedBox(width: 8),
      Text(title, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
    ]);
  }

  Widget _buildInput(TextEditingController ctrl, String hint, {bool obscure = false, int maxLines = 1, IconData? icon}) {
    return TextField(
      controller: ctrl,
      obscureText: obscure,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white, fontSize: 13),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.2)),
        prefixIcon: icon != null ? Icon(icon, color: Colors.white.withValues(alpha: 0.25), size: 16) : null,
        filled: true, fillColor: Colors.white.withValues(alpha: 0.04),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primaryLight)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        isDense: true,
      ),
      onChanged: (_) => setState(() {}),
    );
  }
}
