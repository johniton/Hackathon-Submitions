/// Resume Builder — Step 5B: Preview + ATS Score + Export
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:hustlr/core/theme/app_colors.dart';
import 'package:hustlr/features/resume_builder/data/resume_models.dart';
import 'package:hustlr/features/resume_builder/data/resume_service.dart';

class ResumePreviewPage extends StatefulWidget {
  final ResumeFlowData flowData;
  const ResumePreviewPage({super.key, required this.flowData});
  @override
  State<ResumePreviewPage> createState() => _ResumePreviewPageState();
}

class _ResumePreviewPageState extends State<ResumePreviewPage> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  bool _downloadingPdf = false;
  bool _downloadingDocx = false;
  String? _pdfPath;
  bool _loadingPdfPreview = true;

  GenerateResult get _result => widget.flowData.result!;
  Map<String, dynamic> get _resume => _result.resumeJson;
  ATSScore get _ats => _result.atsScore;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _fetchPdf();
  }

  Future<void> _fetchPdf() async {
    try {
      final bytes = await ResumeService.exportPdf(_resume, widget.flowData.templateName);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/resume_preview.pdf');
      await file.writeAsBytes(bytes);
      if (mounted) {
        setState(() {
          _pdfPath = file.path;
          _loadingPdfPreview = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingPdfPreview = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load PDF preview: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _downloadPdf() async {
    if (_pdfPath == null) return;
    setState(() => _downloadingPdf = true);
    try {
      final bytes = await File(_pdfPath!).readAsBytes();
      final dir = await getApplicationDocumentsDirectory();
      final path = '${dir.path}/resume_${DateTime.now().millisecondsSinceEpoch}.pdf';
      await File(path).writeAsBytes(bytes);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF saved: $path'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF failed: $e'), backgroundColor: AppColors.error),
        );
      }
    }
    setState(() => _downloadingPdf = false);
  }

  Future<void> _downloadDocx() async {
    setState(() => _downloadingDocx = true);
    try {
      final bytes = await ResumeService.exportDocx(_resume);
      final dir = await getApplicationDocumentsDirectory();
      final path = '${dir.path}/resume_${DateTime.now().millisecondsSinceEpoch}.docx';
      await File(path).writeAsBytes(bytes);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('DOCX saved: $path'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('DOCX failed: $e'), backgroundColor: AppColors.error),
        );
      }
    }
    setState(() => _downloadingDocx = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: Colors.transparent, elevation: 0,
        title: const Text('Your Resume', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.home, size: 20),
            onPressed: () => Navigator.popUntil(context, (r) => r.isFirst),
          ),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: AppColors.primaryLight,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white38,
          tabs: const [
            Tab(text: 'PREVIEW'),
            Tab(text: 'ATS SCORE'),
          ],
        ),
      ),
      body: TabBarView(controller: _tabCtrl, children: [
        _buildPreviewTab(),
        _buildAtsTab(),
      ]),
    );
  }

  Widget _buildPreviewTab() {
    return Column(children: [
      Expanded(
        child: _loadingPdfPreview
          ? const Center(child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: AppColors.primaryLight),
                SizedBox(height: 16),
                Text('AI is finalizing your PDF layout...', style: TextStyle(color: Colors.white70)),
              ],
            ))
          : _pdfPath == null
              ? const Center(child: Text('Could not generate PDF preview.', style: TextStyle(color: Colors.red)))
              : Container(
                  margin: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 8))],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: PDFView(
                      filePath: _pdfPath,
                      enableSwipe: true,
                      swipeHorizontal: false,
                      autoSpacing: false,
                      pageFling: false,
                    ),
                  ),
                ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Row(children: [
          Expanded(child: _exportButton('Save PDF', LucideIcons.fileDown, _downloadingPdf, _downloadPdf)),
          const SizedBox(width: 12),
          Expanded(child: _exportButton('Save DOCX', LucideIcons.fileText, _downloadingDocx, _downloadDocx)),
        ]),
      ),
    ]);
  }

  Widget _buildAtsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(children: [
        // Score gauge
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [_scoreColor(_ats.score).withValues(alpha: 0.15), Colors.white.withValues(alpha: 0.03)],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _scoreColor(_ats.score).withValues(alpha: 0.3)),
          ),
          child: Column(children: [
            Text('ATS SCORE', style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 2)),
            const SizedBox(height: 12),
            Text('${_ats.score}', style: TextStyle(color: _scoreColor(_ats.score), fontSize: 56, fontWeight: FontWeight.w900)),
            Text('/100', style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 16)),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: _ats.score / 100, minHeight: 8,
                backgroundColor: Colors.white.withValues(alpha: 0.08),
                valueColor: AlwaysStoppedAnimation(_scoreColor(_ats.score)),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 20),

        // Matched keywords
        if (_ats.matchedKeywords.isNotEmpty) ...[
          _sectionHeader('Matched Keywords', LucideIcons.checkCircle, Colors.green),
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 6, children: _ats.matchedKeywords.map((k) => _chip(k, Colors.green)).toList()),
          const SizedBox(height: 20),
        ],

        // Missing keywords
        if (_ats.missingKeywords.isNotEmpty) ...[
          _sectionHeader('Missing Keywords', LucideIcons.alertCircle, Colors.red),
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 6, children: _ats.missingKeywords.map((k) => _chip(k, Colors.red)).toList()),
          const SizedBox(height: 20),
        ],

        // Suggestions
        if (_ats.suggestions.isNotEmpty) ...[
          _sectionHeader('Improvement Suggestions', LucideIcons.lightbulb, Colors.amber),
          const SizedBox(height: 8),
          ...List.generate(_ats.suggestions.length, (i) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${i + 1}. ', style: TextStyle(color: Colors.amber.withValues(alpha: 0.7), fontSize: 12, fontWeight: FontWeight.w700)),
              Expanded(child: Text(_ats.suggestions[i], style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12, height: 1.4))),
            ]),
          )),
        ],
        const SizedBox(height: 20),
      ]),
    );
  }



  Widget _exportButton(String label, IconData icon, bool loading, VoidCallback onTap) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: loading
          ? const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)))
          : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text('Download $label', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
            ]),
      ),
    );
  }

  Widget _sectionHeader(String title, IconData icon, Color color) {
    return Row(children: [
      Icon(icon, color: color, size: 16),
      const SizedBox(width: 8),
      Text(title, style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
    ]);
  }

  Widget _chip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(text, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }

  Color _scoreColor(int score) {
    if (score >= 80) return Colors.green;
    if (score >= 60) return Colors.amber;
    if (score >= 40) return Colors.orange;
    return Colors.red;
  }
}
