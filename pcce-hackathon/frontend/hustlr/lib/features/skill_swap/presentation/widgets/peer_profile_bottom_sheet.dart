import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:hustlr/core/theme/app_colors.dart';
import 'package:hustlr/features/skill_swap/domain/models/skill_swap_models.dart';

class PeerProfileBottomSheet extends StatefulWidget {
  final SkillSwapUser peer;
  const PeerProfileBottomSheet({super.key, required this.peer});

  static Future<void> show(BuildContext context, SkillSwapUser peer) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PeerProfileBottomSheet(peer: peer),
    );
  }

  @override
  State<PeerProfileBottomSheet> createState() => _PeerProfileBottomSheetState();
}

class _PeerProfileBottomSheetState extends State<PeerProfileBottomSheet> {
  final _db = Supabase.instance.client;
  bool _loading = true;
  Map<String, dynamic>? _profile;
  List<Map<String, dynamic>> _certificates = [];

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    try {
      final res = await _db.from('users').select().eq('id', widget.peer.id).maybeSingle();
      final certs = await _db.from('certificates').select().eq('user_id', widget.peer.id);
      if (mounted) {
        setState(() {
          _profile = res;
          _certificates = List<Map<String, dynamic>>.from(certs);
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Failed to load peer profile: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _launchUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Could not launch $url: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      padding: EdgeInsets.fromLTRB(20, 24, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                child: Text(widget.peer.avatar, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 24)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.peer.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    const SizedBox(height: 2),
                    Text(widget.peer.city, style: const TextStyle(color: AppColors.textSecondaryLight, fontSize: 14)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (_loading)
            const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
          else ...[
            const Text('About', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            if (_profile?['bio'] != null && _profile!['bio'].toString().isNotEmpty)
              Text(_profile!['bio'], style: const TextStyle(color: AppColors.textSecondaryLight, fontSize: 14))
            else
              const Text('No bio provided yet.', style: TextStyle(color: AppColors.textSecondaryLight, fontSize: 14, fontStyle: FontStyle.italic)),
            const SizedBox(height: 20),

            if (_profile?['github_url'] != null && _profile!['github_url'].toString().isNotEmpty) ...[
              _buildLinkRow(LucideIcons.github, 'GitHub', _profile!['github_url']),
              const SizedBox(height: 12),
            ],
            if (_profile?['linkedin_url'] != null && _profile!['linkedin_url'].toString().isNotEmpty) ...[
              _buildLinkRow(LucideIcons.linkedin, 'LinkedIn', _profile!['linkedin_url']),
              const SizedBox(height: 20),
            ],
            const Text('Certificates', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            if (_certificates.isEmpty)
              const Text('No certificates uploaded yet.', style: TextStyle(color: AppColors.textSecondaryLight, fontSize: 14))
            else
              ..._certificates.map((c) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(LucideIcons.award, color: AppColors.primary, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(c['title'] ?? 'Certificate', style: const TextStyle(fontWeight: FontWeight.bold)),
                            if (c['issuer'] != null)
                              Text(c['issuer'], style: const TextStyle(color: AppColors.textSecondaryLight, fontSize: 12)),
                          ],
                        ),
                      ),
                      if (c['credential_url'] != null && c['credential_url'].toString().isNotEmpty)
                        IconButton(
                          icon: const Icon(LucideIcons.externalLink, size: 16),
                          onPressed: () => _launchUrl(c['credential_url']),
                        ),
                    ],
                  ),
                ),
              )),
          ],
        ],
      ),
    );
  }

  Widget _buildLinkRow(IconData icon, String label, String url) {
    return GestureDetector(
      onTap: () => _launchUrl(url),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.accent),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          const Spacer(),
          const Icon(LucideIcons.externalLink, size: 16, color: AppColors.textSecondaryLight),
        ],
      ),
    );
  }
}
