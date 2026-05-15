import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hustlr/config.dart';
import 'package:hustlr/core/theme/app_theme.dart';
import 'package:hustlr/core/theme/app_colors.dart';
import 'features/auth/presentation/pages/login_page.dart';
import 'features/auth/presentation/pages/register_page.dart';
import 'features/auth/presentation/pages/otp_verification_page.dart';

// Home
import 'features/home/presentation/pages/dashboard_page.dart';

// Jobs
import 'features/jobs/presentation/pages/job_discovery_page.dart';
import 'features/jobs/presentation/pages/map_jobs_page.dart';
import 'features/jobs/presentation/pages/saved_jobs_page.dart';
import 'features/jobs/presentation/pages/job_email_inbox_page.dart';
import 'features/salary/presentation/pages/salary_intelligence_page.dart';

// AI Interview
import 'features/ai_interview/presentation/pages/interview_dashboard_page.dart';
import 'features/ai_interview/presentation/pages/mock_interview_page.dart';
import 'features/ai_interview/presentation/pages/interview_results_page.dart';
import 'features/ai_interview/presentation/pages/interview_setup_page.dart';
import 'features/counsellor/presentation/pages/career_counsellor_chat_page.dart';

// Skill Swap
import 'features/skill_swap/presentation/pages/skill_swap_page.dart';

// Resume
import 'features/resume_builder/presentation/pages/resume_builder_dashboard_page.dart';
import 'features/resume_builder/presentation/pages/ats_analysis_page.dart';

// Community
import 'features/community/presentation/pages/social_feed_page.dart';
import 'features/community/presentation/pages/leaderboard_page.dart';
import 'features/community/presentation/pages/challenges_page.dart';
import 'features/community/presentation/pages/alumni_network_page.dart';

// Roadmap
import 'features/roadmap/presentation/pages/roadmap_dashboard_page.dart';
import 'features/roadmap/presentation/pages/skill_gap_analysis_page.dart';
import 'features/roadmap/presentation/pages/daily_skill_pulse_page.dart';

// Learn Skills
import 'features/learn_skills/presentation/pages/learn_skills_page.dart';

// Flashcards
import 'features/flashcards/presentation/pages/flashcard_dashboard_page.dart';
import 'features/flashcards/presentation/pages/deck_view_page.dart';

// Profile
import 'features/profile/presentation/pages/user_profile_page.dart';
import 'features/profile/presentation/pages/certificate_vault_page.dart';
import 'features/profile/presentation/pages/peer_benchmarking_page.dart';
import 'features/profile/presentation/pages/portfolio_showcase_page.dart';

// Company Board
import 'features/company_board/presentation/pages/company_portal_page.dart';
import 'features/company_board/presentation/pages/company_jobs_page.dart';
import 'features/company_board/presentation/pages/company_reviews_page.dart';
import 'features/college_board/presentation/pages/college_portal_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await dotenv.load(fileName: ".env");
  
  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
  );

  runApp(const SkillMapApp());
}

class SkillMapApp extends StatelessWidget {
  const SkillMapApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hustlr',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: const LoginPage(),
    );
  }
}

// ─── Main App Shell ───────────────────────────────────────────────────────────

class MainAppShell extends StatefulWidget {
  const MainAppShell({super.key});

  @override
  State<MainAppShell> createState() => _MainAppShellState();
}

class _MainAppShellState extends State<MainAppShell> with TickerProviderStateMixin {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    DashboardPage(),
    JobDiscoveryPage(),
    SkillSwapPage(),     // Skill Swap replaces Community in the tab bar
    SocialFeedPage(),    // Community moved here
    InterviewDashboardPage(), // AI Interview replaces Hub
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      drawer: const Drawer(
        child: _MorePage(),
      ),
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : const Color(0xFFF5F8F2),
          boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.08), blurRadius: 20, offset: const Offset(0, -5))],
          border: Border(top: BorderSide(color: AppColors.primary.withValues(alpha: 0.08))),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _navItem(0, LucideIcons.home, 'Home'),
                _navItem(1, LucideIcons.briefcase, 'Jobs'),
                _centerButton(),
                _navItem(3, LucideIcons.users, 'Community'),
                _navItem(4, LucideIcons.bot, 'Interview'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _navItem(int index, IconData icon, String label) {
    final selected = _currentIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          AnimatedScale(
            scale: selected ? 1.15 : 1.0,
            duration: const Duration(milliseconds: 200),
            child: Icon(icon, color: selected ? AppColors.primaryDark : AppColors.textSecondaryLight, size: 22),
          ),
          const SizedBox(height: 3),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: selected
                ? Text(label, key: ValueKey(label), style: const TextStyle(color: AppColors.primaryDark, fontSize: 11, fontWeight: FontWeight.bold))
                : const SizedBox.shrink(),
          ),
        ]),
      ),
    );
  }

  Widget _centerButton() {
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = 2), // Skill Swap tab
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: 54, height: 54,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: _currentIndex == 2
              ? AppColors.purpleGradient
              : AppColors.primaryGradient,
          boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.35), blurRadius: 14, offset: const Offset(0, 4))],
        ),
        child: const Icon(LucideIcons.refreshCcw, color: Colors.white, size: 24),
      ),
    );
  }
}

// ─── More / Feature Hub Page ──────────────────────────────────────────────────

class _MorePage extends StatelessWidget {
  const _MorePage();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sections = [
      {
        'title': 'AI Tools',
        'items': [
          _FeatureItem('AI Interview', LucideIcons.bot, AppColors.primaryGradient, () => Navigator.push(context, _route(const InterviewDashboardPage()))),
          _FeatureItem('Mock Interview', LucideIcons.mic, AppColors.purpleGradient, () => Navigator.push(context, _route(const InterviewSetupPage()))),
          _FeatureItem('Interview Results', LucideIcons.barChart2, AppColors.tealGradient, () => Navigator.push(context, _route(const InterviewSetupPage()))),
          _FeatureItem('Skill Gap', LucideIcons.target, AppColors.orangeGradient, () => Navigator.push(context, _route(const SkillGapAnalysisPage()))),
          _FeatureItem('Counsellor', LucideIcons.messageSquare, AppColors.primaryGradient, () => Navigator.push(context, _route(const CareerCounsellorChatPage()))),
        ],
      },
      {
        'title': 'Resume & Jobs',
        'items': [
          _FeatureItem('Resume Builder', LucideIcons.fileText, AppColors.purpleGradient, () => Navigator.push(context, _route(const ResumeBuilderDashboardPage()))),
          _FeatureItem('ATS Analysis', LucideIcons.searchCode, AppColors.primaryGradient, () => Navigator.push(context, _route(const AtsAnalysisPage()))),
          _FeatureItem('Saved Jobs', LucideIcons.bookmark, AppColors.orangeGradient, () => Navigator.push(context, _route(const SavedJobsPage()))),
          _FeatureItem('Map Jobs', LucideIcons.mapPin, AppColors.tealGradient, () => Navigator.push(context, _route(const MapJobsPage()))),
          _FeatureItem('Job Inbox', LucideIcons.mail, AppColors.orchidGradient, () => Navigator.push(context, _route(const JobEmailInboxPage()))),
          _FeatureItem('Salary Intel', LucideIcons.indianRupee, AppColors.primaryGradient, () => Navigator.push(context, _route(const SalaryIntelligencePage()))),
        ],
      },
      {
        'title': 'Skill Swap',
        'items': [
          _FeatureItem('Skill Swap', LucideIcons.refreshCcw, AppColors.tealGradient, () => Navigator.push(context, _route(const SkillSwapPage()))),
        ],
      },
      {
        'title': 'Learning',
        'items': [
          _FeatureItem('Learn Skills', LucideIcons.bookOpen, AppColors.tealGradient, () => Navigator.push(context, _route(const LearnSkillsPage()))),
          _FeatureItem('Roadmap', LucideIcons.map, AppColors.primaryGradient, () => Navigator.push(context, _route(const RoadmapDashboardPage()))),
          _FeatureItem('Skill Pulse', LucideIcons.flame, AppColors.orangeGradient, () => Navigator.push(context, _route(const DailySkillPulsePage()))),
          _FeatureItem('Flashcards', LucideIcons.layers, AppColors.tealGradient, () => Navigator.push(context, _route(const FlashcardDashboardPage()))),
          _FeatureItem('Practice Deck', LucideIcons.playCircle, AppColors.purpleGradient, () => Navigator.push(context, _route(const DeckViewPage()))),
        ],
      },
      {
        'title': 'Community',
        'items': [
          _FeatureItem('Leaderboard', LucideIcons.trophy, AppColors.orangeGradient, () => Navigator.push(context, _route(const LeaderboardPage()))),
          _FeatureItem('Challenges', LucideIcons.zap, AppColors.primaryGradient, () => Navigator.push(context, _route(const ChallengesPage()))),
          _FeatureItem('Alumni Network', LucideIcons.users, AppColors.tealGradient, () => Navigator.push(context, _route(const AlumniNetworkPage()))),
        ],
      },
      {
        'title': 'Profile & Docs',
        'items': [
          _FeatureItem('My Profile', LucideIcons.user, AppColors.purpleGradient, () => Navigator.push(context, _route(const UserProfilePage()))),
          _FeatureItem('Certificate Vault', LucideIcons.shield, AppColors.tealGradient, () => Navigator.push(context, _route(const CertificateVaultPage()))),
          _FeatureItem('Peer Benchmarking', LucideIcons.trendingUp, AppColors.primaryGradient, () => Navigator.push(context, _route(const PeerBenchmarkingPage()))),
          _FeatureItem('Portfolio', LucideIcons.folderHeart, AppColors.orangeGradient, () => Navigator.push(context, _route(const PortfolioShowcasePage()))),
        ],
      },
      {
        'title': 'Enterprise & Portals',
        'items': [
          _FeatureItem('Company Portal', LucideIcons.building2, AppColors.purpleGradient, () => Navigator.push(context, _route(const CompanyPortalPage()))),
          _FeatureItem('Applicants', LucideIcons.users, AppColors.orangeGradient, () => Navigator.push(context, _route(const CompanyJobsPage()))),
          _FeatureItem('Company Reviews', LucideIcons.star, AppColors.tealGradient, () => Navigator.push(context, _route(const CompanyReviewsPage()))),
          _FeatureItem('College Portal', LucideIcons.graduationCap, AppColors.primaryGradient, () => Navigator.push(context, _route(const CollegePortalPage()))),
        ],
      },
    ];

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Text('All Features', style: Theme.of(context).textTheme.headlineLarge),
              ),
            ),
            for (final section in sections)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(section['title'] as String, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.textSecondaryLight)),
                      const SizedBox(height: 12),
                      GridView.count(
                        crossAxisCount: 4,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 0.85,
                        children: (section['items'] as List<_FeatureItem>).map((item) => _buildFeatureTile(item, isDark)).toList(),
                      ),
                    ],
                  ),
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureTile(_FeatureItem item, bool isDark) {
    return GestureDetector(
      onTap: item.onTap,
      child: Column(children: [
        Container(
          width: 56, height: 56,
          decoration: BoxDecoration(gradient: item.gradient, borderRadius: BorderRadius.circular(16)),
          child: Icon(item.icon, color: Colors.white, size: 24),
        ),
        const SizedBox(height: 6),
        Text(item.label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
      ]),
    );
  }

  Route _route(Widget page) => MaterialPageRoute(builder: (_) => page);
}

class _FeatureItem {
  final String label;
  final IconData icon;
  final LinearGradient gradient;
  final VoidCallback onTap;
  const _FeatureItem(this.label, this.icon, this.gradient, this.onTap);
}
