import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:hustlr/core/theme/app_colors.dart';
import 'package:hustlr/core/widgets/glass_card.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:hustlr/core/services/session_service.dart';
import 'package:url_launcher/url_launcher.dart';

class CertificateVaultPage extends StatefulWidget {
  const CertificateVaultPage({super.key});

  @override
  State<CertificateVaultPage> createState() => _CertificateVaultPageState();
}

class _CertificateVaultPageState extends State<CertificateVaultPage> {
  final _db = Supabase.instance.client;
  bool _loading = true;
  bool _uploading = false;
  List<Map<String, dynamic>> _certificates = [];

  @override
  void initState() {
    super.initState();
    _loadCerts();
  }

  Future<void> _loadCerts() async {
    final userId = await SessionService.getId();
    if (userId == null) return;
    try {
      final res = await _db.from('user_certificates').select().eq('user_id', userId).order('created_at', ascending: false);
      if (mounted) {
        setState(() {
          _certificates = List<Map<String, dynamic>>.from(res ?? []);
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading certs: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _uploadCertificate() async {
    final userId = await SessionService.getId();
    if (userId == null) return;

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;
    
    final file = result.files.first;
    if (file.bytes == null) return;

    // Ask user for a title
    String? title = await showDialog<String>(
      context: context,
      builder: (context) {
        final ctrl = TextEditingController(text: file.name.split('.').first);
        return AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: const Text('Certificate Title', style: TextStyle(color: Colors.white)),
          content: TextField(
            controller: ctrl,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(hintText: 'e.g. AWS Certified', hintStyle: TextStyle(color: Colors.white38)),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(onPressed: () => Navigator.pop(context, ctrl.text), child: const Text('Save')),
          ],
        );
      }
    );

    if (title == null || title.isEmpty) return;

    setState(() => _uploading = true);
    try {
      final ext = file.extension ?? 'pdf';
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_$userId.$ext';
      final path = 'certificates/$fileName';

      // Upload to storage
      await _db.storage.from('user-documents').uploadBinary(path, file.bytes!);
      final fileUrl = _db.storage.from('user-documents').getPublicUrl(path);

      // Save to db
      await _db.from('user_certificates').insert({
        'user_id': userId,
        'title': title,
        'file_url': fileUrl,
      });

      _loadCerts();
    } catch (e) {
      debugPrint('Upload error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error uploading: $e')));
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(title: const Text('Document Vault')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Certificates', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 14),
                if (_certificates.isEmpty)
                  const Text('No certificates uploaded yet.', style: TextStyle(color: Colors.grey)),
                if (_certificates.isNotEmpty)
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.1,
                    children: _certificates.map((c) => _certCard(
                      c['title'] ?? 'Certificate',
                      '', 
                      AppColors.primary, 
                      LucideIcons.fileBadge, 
                      isDark,
                      onTap: () {
                        if (c['file_url'] != null) {
                          launchUrl(Uri.parse(c['file_url']));
                        }
                      }
                    )).toList(),
                  ),
                const SizedBox(height: 28),
                // Hardcoded other docs
                Text('Other Documents', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 14),
                _docRow('Resume_v3.pdf', '245 KB', LucideIcons.fileText, AppColors.primary, isDark),
                const SizedBox(height: 10),
                _docRow('10th_Marksheet.pdf', '1.2 MB', LucideIcons.fileCheck, AppColors.success, isDark),
              ]),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _uploading ? null : _uploadCertificate,
        backgroundColor: AppColors.primary,
        child: _uploading 
          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
          : const Icon(LucideIcons.upload, color: Colors.white),
      ),
    );
  }

  Widget _certCard(String title, String issuer, Color color, IconData icon, bool isDark, {bool isAdd = false, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isAdd ? (isDark ? AppColors.surfaceDark : Colors.white) : color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isAdd ? (isDark ? Colors.white12 : Colors.black12) : color.withOpacity(0.25)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Icon(icon, color: isAdd ? AppColors.textSecondaryLight : color, size: 28),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isAdd ? AppColors.textSecondaryLight : null), maxLines: 2, overflow: TextOverflow.ellipsis),
            if (issuer.isNotEmpty) Text(issuer, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
          ]),
        ]),
      ),
    );
  }

  Widget _docRow(String name, String size, IconData icon, Color color, bool isDark) {
    return GlassCard(
      padding: const EdgeInsets.all(14),
      borderRadius: 12,
      child: Row(children: [
        Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Icon(icon, color: color, size: 18)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          Text(size, style: const TextStyle(color: AppColors.textSecondaryLight, fontSize: 11)),
        ])),
        const Icon(LucideIcons.moreVertical, size: 18, color: AppColors.textSecondaryLight),
      ]),
    );
  }
}
