/// Resume Builder — Step 3: Job Description, Certificates, Additional Info
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:file_picker/file_picker.dart';
import 'package:hustlr/core/theme/app_colors.dart';
import 'package:hustlr/features/resume_builder/data/resume_models.dart';
import 'package:hustlr/features/resume_builder/data/resume_service.dart';
import 'package:hustlr/features/resume_builder/presentation/pages/resume_templates_page.dart';

class ResumeDetailsPage extends StatefulWidget {
  final ResumeFlowData flowData;
  const ResumeDetailsPage({super.key, required this.flowData});
  @override
  State<ResumeDetailsPage> createState() => _ResumeDetailsPageState();
}

class _ResumeDetailsPageState extends State<ResumeDetailsPage> {
  final _jdCtrl = TextEditingController();
  final _extraCtrl = TextEditingController();
  bool _jdIsUrl = false;
  final List<CertificateInfo> _certs = [];
  bool _uploadingCert = false;

  Future<void> _pickCertificate() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg'],
      allowMultiple: true,
    );
    if (result == null) return;

    for (final file in result.files) {
      if (file.path == null) continue;
      setState(() => _uploadingCert = true);
      try {
        final cert = await ResumeService.ocrCertificate(file.path!, file.name);
        setState(() => _certs.add(cert));
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('OCR failed: ${file.name}'), backgroundColor: AppColors.error),
          );
        }
      }
    }
    setState(() => _uploadingCert = false);
  }

  void _continue() {
    widget.flowData.jdText = _jdCtrl.text.trim();
    widget.flowData.certificates = _certs;
    widget.flowData.extraInfo = _extraCtrl.text.trim();

    Navigator.push(context, MaterialPageRoute(
      builder: (_) => ResumeTemplatePicker(flowData: widget.flowData),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: Colors.transparent, elevation: 0,
        title: const Text('Add Details', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _buildProgress(3, 5),
          const SizedBox(height: 24),

          // Job Description
          _sectionTitle('Job Description', LucideIcons.briefcase),
          const SizedBox(height: 6),
          Text('Paste a JD to tailor your resume. Optional but recommended.', style: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 12)),
          const SizedBox(height: 10),

          // Toggle URL / Text
          Row(children: [
            _toggleChip('Paste Text', !_jdIsUrl, () => setState(() => _jdIsUrl = false)),
            const SizedBox(width: 8),
            _toggleChip('Paste URL', _jdIsUrl, () => setState(() => _jdIsUrl = true)),
          ]),
          const SizedBox(height: 10),
          _buildInput(_jdCtrl, _jdIsUrl ? 'https://jobs.example.com/posting/123' : 'Paste job description here...', maxLines: _jdIsUrl ? 1 : 5),

          const SizedBox(height: 28),

          // Certificates
          _sectionTitle('Certificates', LucideIcons.award),
          const SizedBox(height: 6),
          Text('Upload certificates — AI will extract the details automatically.', style: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 12)),
          const SizedBox(height: 10),

          GestureDetector(
            onTap: _uploadingCert ? null : _pickCertificate,
            child: Container(
              height: 70, width: double.infinity,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white.withValues(alpha: 0.12), width: 1.5),
                borderRadius: BorderRadius.circular(12),
                color: Colors.white.withValues(alpha: 0.03),
              ),
              child: _uploadingCert
                ? const Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)))
                : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(LucideIcons.uploadCloud, color: Colors.white.withValues(alpha: 0.3), size: 22),
                    const SizedBox(width: 10),
                    Text('Upload PDF or Image', style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 13, fontWeight: FontWeight.w600)),
                  ]),
            ),
          ),

          // Certificate cards
          if (_certs.isNotEmpty) ...[
            const SizedBox(height: 12),
            ..._certs.asMap().entries.map((e) => _certCard(e.value, e.key)),
          ],

          const SizedBox(height: 28),

          // Additional Info
          _sectionTitle('Additional Info', LucideIcons.penTool),
          const SizedBox(height: 6),
          Text('Achievements, hobbies, volunteer work, or any custom notes.', style: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 12)),
          const SizedBox(height: 10),
          _buildInput(_extraCtrl, 'e.g., Hackathon winner, Open source contributor, Led college coding club...', maxLines: 4),

          const SizedBox(height: 36),

          // Continue
          GestureDetector(
            onTap: _continue,
            child: Container(
              height: 56, width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [AppColors.primaryLight, AppColors.primary]),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Center(
                child: Text('Continue — Pick Template', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ]),
      ),
    );
  }

  Widget _certCard(CertificateInfo cert, int idx) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(children: [
        const Icon(LucideIcons.award, color: AppColors.primaryLight, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(cert.certName.isNotEmpty ? cert.certName : 'Certificate ${idx + 1}', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
          if (cert.issuer.isNotEmpty)
            Text(cert.issuer, style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 11)),
          if (cert.skills.isNotEmpty)
            Wrap(spacing: 4, runSpacing: 4, children: cert.skills.map((s) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: AppColors.primaryLight.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
              child: Text(s, style: TextStyle(color: AppColors.primaryLight, fontSize: 9, fontWeight: FontWeight.w600)),
            )).toList()),
        ])),
        GestureDetector(
          onTap: () => setState(() => _certs.removeAt(idx)),
          child: Icon(LucideIcons.x, color: Colors.white.withValues(alpha: 0.3), size: 16),
        ),
      ]),
    );
  }

  Widget _toggleChip(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: active ? AppColors.primaryLight.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: active ? AppColors.primaryLight.withValues(alpha: 0.5) : Colors.transparent),
        ),
        child: Text(label, style: TextStyle(color: active ? AppColors.primaryLight : Colors.white.withValues(alpha: 0.4), fontSize: 12, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _sectionTitle(String title, IconData icon) {
    return Row(children: [
      Icon(icon, color: AppColors.primaryLight, size: 18),
      const SizedBox(width: 8),
      Text(title, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
    ]);
  }

  Widget _buildInput(TextEditingController ctrl, String hint, {int maxLines = 1}) {
    return TextField(
      controller: ctrl, maxLines: maxLines,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.2)),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.05),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primaryLight)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
