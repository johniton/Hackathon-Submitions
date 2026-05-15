import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:hustlr/core/theme/app_colors.dart';
import 'package:hustlr/core/widgets/skill_chip.dart';
import 'package:hustlr/core/services/session_service.dart';
import 'package:hustlr/features/auth/presentation/pages/login_page.dart';
import 'package:hustlr/features/profile/presentation/pages/certificate_vault_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class UserProfilePage extends StatefulWidget {
  const UserProfilePage({super.key});

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  final _db = Supabase.instance.client;
  bool _loading = true;
  Map<String, dynamic>? _userProfile;
  List<Map<String, dynamic>> _certificates = [];

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final userId = await SessionService.getId();
    if (userId == null) return;
    try {
      final res = await _db.from('users').select().eq('id', userId).maybeSingle();
      final certs = await _db.from('certificates').select().eq('user_id', userId);
      if (mounted) {
        setState(() {
          _userProfile = res;
          _certificates = List<Map<String, dynamic>>.from(certs);
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading profile: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _editProfile() async {
    final bioCtrl = TextEditingController(text: _userProfile?['bio'] ?? '');
    final githubCtrl = TextEditingController(text: _userProfile?['github_url'] ?? '');
    final linkedinCtrl = TextEditingController(text: _userProfile?['linkedin_url'] ?? '');

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E293B),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Edit Profile', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              _buildField('Bio', bioCtrl, maxLines: 3),
              const SizedBox(height: 12),
              _buildField('GitHub URL', githubCtrl),
              const SizedBox(height: 12),
              _buildField('LinkedIn URL', linkedinCtrl),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    setState(() => _loading = true);
                    await _db.from('users').update({
                      'bio': bioCtrl.text,
                      'github_url': githubCtrl.text,
                      'linkedin_url': linkedinCtrl.text,
                    }).eq('id', _userProfile!['id']);
                    _loadProfile();
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: const Text('Save Changes', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              )
            ],
          ),
        );
      }
    );
  }

  Widget _buildField(String label, TextEditingController ctrl, {int maxLines = 1}) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(backgroundColor: Color(0xFF0F172A), body: Center(child: CircularProgressIndicator()));
    }

    final name = _userProfile?['name'] ?? 'Hustlr User';
    final email = _userProfile?['email'] ?? '';
    final bio = _userProfile?['bio'] ?? 'Update your bio to tell the world about yourself!';
    final github = _userProfile?['github_url'] as String?;
    final linkedin = _userProfile?['linkedin_url'] as String?;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(children: [
            // Top gradient section
            Container(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
              decoration: const BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.only(bottomLeft: Radius.circular(32), bottomRight: Radius.circular(32)),
              ),
              child: Column(children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('My Profile', style: TextStyle(color: Colors.white70, fontSize: 14)),
                  GestureDetector(
                    onTap: _editProfile,
                    child: const Icon(LucideIcons.edit2, color: Colors.white70, size: 20),
                  )
                ]),
                const SizedBox(height: 20),
                // Replaced hardcoded avatar
                CircleAvatar(
                  radius: 42, 
                  backgroundColor: Colors.white24,
                  child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'U', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
                const SizedBox(height: 12),
                Text(name, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(email, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 16),
                
                if (bio.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(bio, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4)),
                  ),
                  const SizedBox(height: 16),
                ],

                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  if (github != null && github.isNotEmpty) ...[
                    GestureDetector(
                      onTap: () => launchUrl(Uri.parse(github)),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(20)),
                        child: const Row(children: [Icon(LucideIcons.github, size: 14, color: Colors.white), SizedBox(width: 6), Text('GitHub', style: TextStyle(color: Colors.white, fontSize: 12))]),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  if (linkedin != null && linkedin.isNotEmpty) ...[
                    GestureDetector(
                      onTap: () => launchUrl(Uri.parse(linkedin)),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(20)),
                        child: const Row(children: [Icon(LucideIcons.linkedin, size: 14, color: Colors.white), SizedBox(width: 6), Text('LinkedIn', style: TextStyle(color: Colors.white, fontSize: 12))]),
                      ),
                    ),
                  ],
                ]),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Career Stats', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white)),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: _statCard('Resume Score', '92/100', LucideIcons.fileText, AppColors.accentPurple)),
                  const SizedBox(width: 12),
                  Expanded(child: _statCard('Interviews', '8 Done', LucideIcons.bot, AppColors.primary)),
                  const SizedBox(width: 12),
                  Expanded(child: _statCard('Job Rank', 'Top 15%', LucideIcons.trendingUp, AppColors.success)),
                ]),
                const SizedBox(height: 28),
                Text('Badges', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white)),
                const SizedBox(height: 12),
                Row(children: [
                  _badge('🏆', 'Top\nContrib'),
                  const SizedBox(width: 12),
                  _badge('⭐', 'Rising\nStar'),
                  const SizedBox(width: 12),
                  _badge('🎯', 'Job\nReady'),
                  const SizedBox(width: 12),
                  _badge('🔥', '7 Day\nStreak'),
                ]),
                const SizedBox(height: 28),
                Text('Documents & Certificates', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white)),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const CertificateVaultPage()));
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withOpacity(0.1))),
                    child: Row(children: [
                      Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.2), borderRadius: BorderRadius.circular(12)), child: const Icon(LucideIcons.fileBadge, color: AppColors.primary, size: 24)),
                      const SizedBox(width: 16),
                      const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Certificate Vault', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                        SizedBox(height: 4),
                        Text('Manage your achievements and documents', style: TextStyle(color: Colors.white54, fontSize: 12)),
                      ])),
                      const Icon(LucideIcons.chevronRight, color: Colors.white54, size: 20),
                    ]),
                  ),
                ),
                const SizedBox(height: 16),
                if (_certificates.isNotEmpty) ...[
                  ..._certificates.map((c) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
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
                                Text(c['title'] ?? 'Certificate', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                if (c['issuer'] != null)
                                  Text(c['issuer'], style: const TextStyle(color: Colors.white54, fontSize: 12)),
                              ],
                            ),
                          ),
                          if (c['credential_url'] != null && c['credential_url'].toString().isNotEmpty)
                            IconButton(
                              icon: const Icon(LucideIcons.externalLink, color: Colors.white54, size: 16),
                              onPressed: () => launchUrl(Uri.parse(c['credential_url']), mode: LaunchMode.externalApplication),
                            ),
                        ],
                      ),
                    ),
                  )),
                ],
                const SizedBox(height: 40),
                Center(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await SessionService.clear();
                      if (context.mounted) {
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(builder: (_) => const LoginPage()),
                          (route) => false,
                        );
                      }
                    },
                    icon: const Icon(LucideIcons.logOut, size: 18, color: AppColors.error),
                    label: const Text('Log Out', style: TextStyle(color: AppColors.error)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.error),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _statCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 8),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(title, style: const TextStyle(color: Colors.white54, fontSize: 11)),
      ]),
    );
  }

  Widget _badge(String emoji, String title) {
    return Container(
      width: 70, height: 70,
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withOpacity(0.1))),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(emoji, style: const TextStyle(fontSize: 22)),
        const SizedBox(height: 4),
        Text(title, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}
