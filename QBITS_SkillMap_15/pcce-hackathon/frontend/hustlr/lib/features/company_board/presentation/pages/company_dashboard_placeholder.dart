import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hustlr/core/theme/app_colors.dart';
import 'package:hustlr/core/services/session_service.dart';
import 'package:hustlr/features/auth/presentation/pages/login_page.dart';
import 'company_create_job_page.dart';
import 'company_applicants_page.dart';

class CompanyDashboardPlaceholder extends StatefulWidget {
  const CompanyDashboardPlaceholder({super.key});

  @override
  State<CompanyDashboardPlaceholder> createState() => _CompanyDashboardPlaceholderState();
}

class _CompanyDashboardPlaceholderState extends State<CompanyDashboardPlaceholder> {
  final _db = Supabase.instance.client;

  String _companyName = '';
  String _companyId = '';
  List<Map<String, dynamic>> _jobs = [];
  List<Map<String, dynamic>> _allUsers = [];
  bool _loading = true;
  int _selectedTab = 0; // 0 = Jobs, 1 = Registered Users

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    _companyName = await SessionService.getName() ?? 'Company';
    _companyId = await SessionService.getId() ?? '';

    final jobsRes = await _db
        .from('job_listings')
        .select('*, job_applications(count)')
        .eq('company_id', _companyId)
        .order('created_at', ascending: false);

    final usersRes = await _db
        .from('users')
        .select('id, name, email, created_at')
        .order('created_at', ascending: false);

    if (mounted) {
      setState(() {
        _jobs = List<Map<String, dynamic>>.from(jobsRes ?? []);
        _allUsers = List<Map<String, dynamic>>.from(usersRes ?? []);
        _loading = false;
      });
    }
  }

  Future<void> _togglePublish(String jobId, bool current) async {
    await _db.from('job_listings').update({'is_published': !current}).eq('id', jobId);
    _load();
  }

  Future<void> _deleteJob(String jobId) async {
    await _db.from('job_listings').delete().eq('id', jobId);
    _load();
  }

  int get _totalApplicants => _jobs.fold(0, (sum, j) {
    final apps = j['job_applications'];
    if (apps is List) return sum + apps.length;
    return sum;
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : const Color(0xFF0F172A),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(isDark),
            // Stats
            if (!_loading) _buildStats(),
            // Tab Bar
            _buildTabBar(),
            // Content
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: Colors.white))
                  : _selectedTab == 0
                      ? _buildJobsList()
                      : _buildUsersList(),
            ),
          ],
        ),
      ),
      floatingActionButton: _selectedTab == 0
          ? FloatingActionButton.extended(
              onPressed: () async {
                await Navigator.push(context, MaterialPageRoute(builder: (_) => const CompanyCreateJobPage()));
                _load();
              },
              backgroundColor: AppColors.primary,
              icon: const Icon(LucideIcons.plus, color: Colors.white),
              label: const Text('Post Job', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            )
          : null,
    );
  }

  Widget _buildHeader(bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(LucideIcons.building2, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_companyName, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                Text('Company Dashboard', style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(LucideIcons.logOut, color: Colors.white54, size: 20),
            onPressed: () async {
              await SessionService.clear();
              if (mounted) {
                Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginPage()));
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStats() {
    final published = _jobs.where((j) => j['is_published'] == true).length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        children: [
          _statCard('Total Jobs', '${_jobs.length}', LucideIcons.briefcase, AppColors.primary),
          const SizedBox(width: 10),
          _statCard('Published', '$published', LucideIcons.globe, const Color(0xFF22C55E)),
          const SizedBox(width: 10),
          _statCard('Applicants', '$_totalApplicants', LucideIcons.users, const Color(0xFFF59E0B)),
          const SizedBox(width: 10),
          _statCard('Users', '${_allUsers.length}', LucideIcons.userCheck, AppColors.accentPurple),
        ],
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 6),
            Text(value, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.w900)),
            Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 9, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        children: [
          _tab(0, 'Job Listings', LucideIcons.briefcase),
          const SizedBox(width: 10),
          _tab(1, 'Registered Users', LucideIcons.users),
        ],
      ),
    );
  }

  Widget _tab(int idx, String label, IconData icon) {
    final sel = _selectedTab == idx;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = idx),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          margin: const EdgeInsets.only(top: 8),
          decoration: BoxDecoration(
            gradient: sel ? AppColors.primaryGradient : null,
            color: sel ? null : Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: sel ? Colors.white : Colors.white38, size: 16),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(color: sel ? Colors.white : Colors.white38, fontSize: 13, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildJobsList() {
    if (_jobs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(LucideIcons.briefcase, color: Colors.white.withValues(alpha: 0.2), size: 60),
            const SizedBox(height: 16),
            Text('No jobs posted yet', style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 16)),
            const SizedBox(height: 8),
            Text('Tap + to post your first job', style: TextStyle(color: Colors.white.withValues(alpha: 0.25), fontSize: 13)),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _jobs.length,
        itemBuilder: (_, i) => _buildJobCard(_jobs[i]),
      ),
    );
  }

  Widget _buildJobCard(Map<String, dynamic> job) {
    final published = job['is_published'] == true;
    final aiEnabled = job['ai_screening_enabled'] == true;
    final apps = job['job_applications'];
    final appCount = apps is List ? apps.length : 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(job['title'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: published ? const Color(0xFF22C55E).withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: published ? const Color(0xFF22C55E).withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.1)),
                  ),
                  child: Text(published ? 'Live' : 'Draft', style: TextStyle(color: published ? const Color(0xFF22C55E) : Colors.white38, fontSize: 11, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                if (job['location'] != null) ...[
                  Icon(LucideIcons.mapPin, size: 12, color: Colors.white.withValues(alpha: 0.35)),
                  const SizedBox(width: 4),
                  Text(job['location']!, style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12)),
                  const SizedBox(width: 12),
                ],
                Icon(LucideIcons.briefcase, size: 12, color: Colors.white.withValues(alpha: 0.35)),
                const SizedBox(width: 4),
                Text(job['job_type'] ?? 'Full-Time', style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12)),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _pillBadge('$appCount Applicants', LucideIcons.users, Colors.white24),
                const SizedBox(width: 8),
                if (aiEnabled) _pillBadge('AI Screen', LucideIcons.bot, AppColors.primary.withValues(alpha: 0.5)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _actionBtn('View Applicants', LucideIcons.users, AppColors.primary, () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => CompanyApplicantsPage(job: job)));
                }),
                const SizedBox(width: 8),
                _actionBtn(published ? 'Unpublish' : 'Publish', published ? LucideIcons.eyeOff : LucideIcons.globe, const Color(0xFF22C55E), () => _togglePublish(job['id'], published)),
                const SizedBox(width: 8),
                _actionBtn('Delete', LucideIcons.trash2, const Color(0xFFEF4444), () => _deleteJob(job['id'])),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _pillBadge(String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _actionBtn(String label, IconData icon, Color color, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 4),
              Flexible(child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUsersList() {
    if (_allUsers.isEmpty) {
      return Center(child: Text('No users registered yet', style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 16)));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _allUsers.length,
      itemBuilder: (_, i) => _buildUserCard(_allUsers[i], i),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user, int idx) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Center(
              child: Text(
                (user['name'] as String? ?? 'U').substring(0, 1).toUpperCase(),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user['name'] ?? 'Unknown', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                Text(user['email'] ?? '', style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('#${idx + 1}', style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 11, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
