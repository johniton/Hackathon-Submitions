import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:hustlr/core/theme/app_colors.dart';
import 'package:hustlr/core/widgets/glass_card.dart';
import 'package:hustlr/features/resume_builder/presentation/pages/resume_builder_dashboard_page.dart';
import 'package:hustlr/features/skill_swap/presentation/pages/skill_swap_page.dart';
import 'package:hustlr/features/ai_interview/presentation/pages/interview_dashboard_page.dart';
import 'package:hustlr/features/learn_skills/presentation/pages/learn_skills_page.dart';
import 'package:hustlr/features/jobs/presentation/pages/job_email_inbox_page.dart';
import 'package:hustlr/features/profile/presentation/pages/user_profile_page.dart';
import 'package:hustlr/features/community/presentation/pages/ai_tech_feed_page.dart';
import 'package:hustlr/features/counsellor/presentation/pages/career_counsellor_chat_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hustlr/core/services/session_service.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> with SingleTickerProviderStateMixin {
  final _db = Supabase.instance.client;
  String _userName = 'Hustlr User';
  String _userAvatar = 'U';
  late AnimationController _quoteAnim;
  late Animation<double> _quoteFade;

  static const _quotes = [
    '"The only way to do great work is to love what you do." — Steve Jobs',
    '"Your limitation — it\'s only your imagination."',
    '"Push yourself, because no one else is going to do it for you."',
    '"Great things never come from comfort zones."',
    '"Dream it. Wish it. Do it."',
    '"Success doesn\'t just find you. You have to go out and get it."',
    '"Don\'t stop when you\'re tired. Stop when you\'re done."',
    '"Wake up with determination. Go to bed with satisfaction."',
    '"The future belongs to those who believe in the beauty of their dreams." — Eleanor Roosevelt',
    '"Code is like humor. When you have to explain it, it\'s bad." — Cory House',
  ];

  late String _currentQuote;

  @override
  void initState() {
    super.initState();
    _currentQuote = _quotes[Random().nextInt(_quotes.length)];
    _quoteAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _quoteFade = CurvedAnimation(parent: _quoteAnim, curve: Curves.easeOutCubic);
    _quoteAnim.forward();
    _loadUser();
  }

  @override
  void dispose() {
    _quoteAnim.dispose();
    super.dispose();
  }

  Future<void> _loadUser() async {
    try {
      final userId = await SessionService.getId();
      if (userId != null) {
        final res = await _db.from('users').select('name').eq('id', userId).maybeSingle();
        if (mounted && res != null) {
          setState(() {
            _userName = res['name'] ?? 'Hustlr User';
            if (_userName.isNotEmpty) {
              _userAvatar = _userName[0].toUpperCase();
            }
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading user in dashboard: $e');
    }
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header Row ────────────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_greeting()},',
                          style: TextStyle(
                            color: AppColors.textSecondaryLight,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _userName,
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Menu icon
                  GestureDetector(
                    onTap: () => Scaffold.of(context).openDrawer(),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(LucideIcons.menu, size: 20, color: AppColors.primaryDark),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Profile Avatar
                  GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UserProfilePage())),
                    child: Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: AppColors.primaryGradient,
                        boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 3))],
                      ),
                      child: Center(child: Text(_userAvatar, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white))),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // ── Motivational Quote ────────────────────────────────────
              FadeTransition(
                opacity: _quoteFade,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primaryLight.withValues(alpha: 0.4),
                        AppColors.accent.withValues(alpha: 0.2),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.12)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(LucideIcons.sparkles, size: 20, color: AppColors.primaryDark),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          _currentQuote,
                          style: TextStyle(
                            color: AppColors.primaryDark,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            fontStyle: FontStyle.italic,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // ── Quick Actions (attractive cards) ──────────────────────
              Text('Quick Actions', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(child: _actionTile(context, 'Tech Feed', LucideIcons.newspaper, AppColors.primaryDark, AppColors.purpleGradient, isDark,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AiTechFeedPage())))),
                  const SizedBox(width: 10),
                  Expanded(child: _actionTile(context, 'Counsellor', LucideIcons.messageSquare, AppColors.primary, AppColors.primaryGradient, isDark,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CareerCounsellorChatPage())))),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _actionTile(context, 'Learn Skills', LucideIcons.bookOpen, AppColors.accent, AppColors.tealGradient, isDark,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LearnSkillsPage())))),
                  const SizedBox(width: 10),
                  Expanded(child: _actionTile(context, 'Resume ATS', LucideIcons.fileText, AppColors.accentPink, AppColors.orchidGradient, isDark,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ResumeBuilderDashboardPage())))),
                ],
              ),

              const SizedBox(height: 28),

              // ── Streak & XP row ────────────────────────────────────
              Row(children: [
                Expanded(child: _miniStatCard('🔥', '8 days', 'Streak', AppColors.accentOrange, isDark)),
                const SizedBox(width: 10),
                Expanded(child: _miniStatCard('⚡', '2,480', 'Total XP', AppColors.primaryDark, isDark)),
                const SizedBox(width: 10),
                Expanded(child: _miniStatCard('🤝', '4', 'Swaps', AppColors.primary, isDark)),
                const SizedBox(width: 10),
                Expanded(child: _miniStatCard('🎯', '12', 'Interviews', AppColors.accentPink, isDark)),
              ]),
              const SizedBox(height: 28),

              // ── Today's plan ───────────────────────────────────────────
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text("Today's Plan", style: Theme.of(context).textTheme.titleLarge),
                Text('3/5 done', style: TextStyle(color: AppColors.success, fontWeight: FontWeight.bold, fontSize: 13)),
              ]),
              const SizedBox(height: 14),
              _todayTask('Review 15 flashcards', 'Flashcards · 10 min', LucideIcons.layers, true, isDark),
              const SizedBox(height: 8),
              _todayTask('Complete mock interview', 'AI Interview · 20 min', LucideIcons.bot, true, isDark),
              const SizedBox(height: 8),
              _todayTask('Update Flutter roadmap', 'Roadmap · 5 min', LucideIcons.map, false, isDark),
              const SizedBox(height: 8),
              _todayTask('Answer 1 community question', 'Community · +50 XP', LucideIcons.messageCircle, false, isDark),
              const SizedBox(height: 28),

              // ── Email Inbox Section ─────────────────────────────────────
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('Job Inbox', style: Theme.of(context).textTheme.titleLarge),
                GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const JobEmailInboxPage())),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                    child: const Text('View All', style: TextStyle(color: AppColors.primaryDark, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const JobEmailInboxPage())),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: AppColors.purpleGradient,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [BoxShadow(color: AppColors.primaryDark.withValues(alpha: 0.25), blurRadius: 14, offset: const Offset(0, 5))],
                  ),
                  child: Row(children: [
                    const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('📬', style: TextStyle(fontSize: 28)),
                    ]),
                    const SizedBox(width: 14),
                    const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('2 new updates', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
                      Text('Google Interview · CRED Offer', style: TextStyle(color: Colors.white70, fontSize: 11)),
                    ])),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10)),
                      child: const Text('Open →', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  ]),
                ),
              ),
              const SizedBox(height: 10),
              _inboxPreviewCard('Google', '📅 Interview Invite', 'May 20, 2:00 PM', AppColors.warning, true, context),
              const SizedBox(height: 8),
              _inboxPreviewCard('CRED', '🎉 Offer Letter', 'Accept by May 18', AppColors.success, true, context),
              const SizedBox(height: 8),
              _inboxPreviewCard('Meesho', '💻 Assessment', 'Due May 16', AppColors.accentPink, false, context),
              const SizedBox(height: 32),

              // Recommended Jobs
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Recommended Roles', style: Theme.of(context).textTheme.titleLarge),
                  TextButton(
                    onPressed: () {},
                    child: const Text('See All', style: TextStyle(color: AppColors.primaryDark)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildJobCard(context, 'Senior Flutter Developer', 'Google', 'Remote', '95% Match', isDark),
              const SizedBox(height: 16),
              _buildJobCard(context, 'Frontend Engineer', 'Spotify', 'New York, NY', '88% Match', isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionTile(BuildContext context, String title, IconData icon, Color color, LinearGradient gradient, bool isDark, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap?.call();
      },
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.15)),
          boxShadow: [BoxShadow(color: color.withValues(alpha: 0.08), blurRadius: 16, offset: const Offset(0, 6))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(gradient: gradient, borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            const SizedBox(height: 14),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            const SizedBox(height: 4),
            Row(children: [
              Icon(LucideIcons.arrowRight, size: 12, color: color),
              const SizedBox(width: 4),
              Text('Open', style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildJobCard(BuildContext context, String title, String company, String location, String match, bool isDark) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      borderRadius: 16,
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primaryDark.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(LucideIcons.briefcase, color: AppColors.primaryDark),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4),
                Text(
                  '$company • $location',
                  style: TextStyle(
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              match,
              style: const TextStyle(color: AppColors.success, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniStatCard(String emoji, String value, String label, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Column(children: [
        Text(emoji, style: const TextStyle(fontSize: 20)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: color)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: AppColors.textSecondaryLight, fontSize: 10)),
      ]),
    );
  }

  Widget _todayTask(String title, String subtitle, IconData icon, bool done, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: done
            ? AppColors.success.withValues(alpha: 0.06)
            : (isDark ? AppColors.surfaceDark : AppColors.surfaceLight),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: done ? AppColors.success.withValues(alpha: 0.25) : AppColors.primary.withValues(alpha: 0.1),
        ),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: done ? AppColors.success.withValues(alpha: 0.1) : AppColors.primary.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 16, color: done ? AppColors.success : AppColors.primary),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, decoration: done ? TextDecoration.lineThrough : null, color: done ? AppColors.textSecondaryLight : AppColors.textPrimaryLight)),
          Text(subtitle, style: const TextStyle(color: AppColors.textSecondaryLight, fontSize: 11)),
        ])),
        if (done) const Icon(LucideIcons.checkCircle2, color: AppColors.success, size: 18),
      ]),
    );
  }

  Widget _inboxPreviewCard(String company, String label, String deadline, Color color, bool urgent, BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const JobEmailInboxPage())),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: urgent ? color.withValues(alpha: 0.05) : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: urgent ? color.withValues(alpha: 0.2) : AppColors.primary.withValues(alpha: 0.1)),
        ),
        child: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
            child: Center(child: Text(company[0], style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 16))),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('$company — $label', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textPrimaryLight)),
            if (deadline.isNotEmpty) Text(deadline, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w500)),
          ])),
          Icon(LucideIcons.chevronRight, size: 14, color: color),
        ]),
      ),
    );
  }
}
