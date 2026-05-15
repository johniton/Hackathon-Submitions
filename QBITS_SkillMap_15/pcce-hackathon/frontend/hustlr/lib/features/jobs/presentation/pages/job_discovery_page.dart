import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:hustlr/core/theme/app_colors.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hustlr/features/resume_builder/presentation/pages/resume_input_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/datasources/job_remote_datasource.dart';
import '../../data/repositories/job_repository_impl.dart';
import 'map_jobs_page.dart';
import 'cold_dm_generator_page.dart';
import '../../domain/models/job_listing_model.dart';
import '../../domain/repositories/job_repository.dart';
import 'job_detail_page.dart';

// ── Filter definitions ──────────────────────────────────────────────────────

enum JobFilter { all, direct, external, remote, fullTime, internship }

extension JobFilterExt on JobFilter {
  String get label {
    switch (this) {
      case JobFilter.all: return 'All Roles';
      case JobFilter.direct: return 'Direct Jobs';
      case JobFilter.external: return 'External';
      case JobFilter.remote: return 'Remote';
      case JobFilter.fullTime: return 'Full-time';
      case JobFilter.internship: return 'Internship';
    }
  }

  Color? get color {
    switch (this) {
      case JobFilter.all: return null;
      case JobFilter.direct: return const Color(0xFF22C55E); // Green for direct
      case JobFilter.external: return AppColors.primary;
      case JobFilter.remote: return AppColors.accent;
      case JobFilter.fullTime: return AppColors.accentPurple;
      case JobFilter.internship: return AppColors.accentOrange;
    }
  }
}

// ── Page ────────────────────────────────────────────────────────────────────

class JobDiscoveryPage extends StatefulWidget {
  const JobDiscoveryPage({super.key});

  @override
  State<JobDiscoveryPage> createState() => _JobDiscoveryPageState();
}

class _JobDiscoveryPageState extends State<JobDiscoveryPage> {
  late final JobRepository _repository;
  final _db = Supabase.instance.client;

  final TextEditingController _searchController = TextEditingController();

  /// Full, unfiltered list returned by the API.
  List<JobListingModel> _allScrapedJobs = [];
  
  /// Full, unfiltered list from Supabase
  List<Map<String, dynamic>> _allSupabaseJobs = [];

  /// Filtered subset shown in the list.
  List<dynamic> _displayedJobs = []; // Can contain both JobListingModel and Map<String, dynamic>

  final Set<String> _bookmarkedJobIds = {};

  JobFilter _activeFilter = JobFilter.all;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _repository = JobRepositoryImpl(datasource: JobRemoteDatasource());
    _searchController.text = '';
    _performSearch();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ── Data ─────────────────────────────────────────────────────────────────

  Future<void> _performSearch({List<String>? userSkillsOverride}) async {
    final query = _searchController.text.trim();

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _allScrapedJobs = [];
      _allSupabaseJobs = [];
      _displayedJobs = [];
    });

    try {
      // 1. Fetch Supabase Jobs
      var supabaseQuery = _db
          .from('job_listings')
          .select('*, companies(name)')
          .eq('is_published', true)
          .order('created_at', ascending: false);
      
      final supabaseRes = await supabaseQuery;
      
      // Filter Supabase jobs locally by query
      final queryLower = query.toLowerCase();
      _allSupabaseJobs = List<Map<String, dynamic>>.from(supabaseRes).where((job) {
        if (queryLower.isEmpty) return true;
        final title = (job['title'] ?? '').toString().toLowerCase();
        final desc = (job['description'] ?? '').toString().toLowerCase();
        final skills = (job['required_skills'] as List?)?.join(' ').toLowerCase() ?? '';
        return title.contains(queryLower) || desc.contains(queryLower) || skills.contains(queryLower);
      }).toList();

      // 2. Fetch Scraped Jobs
      final params = SearchJobsParams(
        keywords: query.isEmpty ? 'Developer' : query, // Default to generic term if empty to avoid api issues
        location: 'India',
        userSkills: userSkillsOverride ?? ['flutter', 'dart', 'firebase', 'python'], // Fallback to example skills
        freshnessDays: 1,
      );

      try {
        final result = await _repository.searchJobs(params);
        if (!mounted) return;
        result.fold(
          (failure) => _errorMessage = failure.message,
          (response) => _allScrapedJobs = response.jobs,
        );
      } catch (e) {
        _errorMessage = e.toString();
      }

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _applyFilter(_activeFilter);
        if (_allSupabaseJobs.isNotEmpty || _allScrapedJobs.isNotEmpty) {
          _errorMessage = null;
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
          _applyFilter(_activeFilter);
          if (_allSupabaseJobs.isNotEmpty || _allScrapedJobs.isNotEmpty) {
            _errorMessage = null;
          }
        });
      }
    }
  }

  Future<void> _useResumeSearch() async {
    HapticFeedback.selectionClick();
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('last_generate_result');
    if (raw == null) {
      // No cached resume — open resume builder
      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute(builder: (_) => const ResumeInputPage()));
      return;
    }

    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final resume = data['resume_json'] as Map<String, dynamic>? ?? {};
      final ats = data['ats_score'] as Map<String, dynamic>? ?? {};

      // Derive keywords and skills
      String keywords = '';
      if (resume['headline'] != null && (resume['headline'] as String).isNotEmpty) {
        keywords = resume['headline'] as String;
      } else if (resume['summary'] != null && (resume['summary'] as String).isNotEmpty) {
        keywords = (resume['summary'] as String).split('.').first;
      } else if ((ats['matched_keywords'] as List?)?.isNotEmpty == true) {
        keywords = (ats['matched_keywords'] as List).first as String;
      } else {
        keywords = _searchController.text.trim().isNotEmpty ? _searchController.text.trim() : 'Software Engineer';
      }

      final skills = <String>[];
      if (resume['skills'] != null && resume['skills'] is List) {
        for (var s in (resume['skills'] as List)) {
          if (s is String && s.trim().isNotEmpty) skills.add(s.trim().toLowerCase());
        }
      }
      if (skills.isEmpty && ats['matched_keywords'] != null && ats['matched_keywords'] is List) {
        for (var s in (ats['matched_keywords'] as List)) {
          if (s is String && s.trim().isNotEmpty) skills.add(s.trim().toLowerCase());
        }
      }

      setState(() {
        _searchController.text = keywords;
      });

      await _performSearch(userSkillsOverride: skills.isNotEmpty ? skills : null);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not load resume data.')));
    }
  }

  void _applyFilter(JobFilter filter) {
    setState(() {
      _activeFilter = filter;
      _displayedJobs = [];

      // Filter Supabase
      final filteredSupabase = _allSupabaseJobs.where((job) {
        final titleL = (job['title'] ?? '').toString().toLowerCase();
        final locL = (job['location'] ?? '').toString().toLowerCase();
        final typeL = (job['job_type'] ?? '').toString().toLowerCase();
        final isIntern = titleL.contains('intern') || typeL.contains('intern');
        
        if (filter == JobFilter.external) return false;
        if (filter == JobFilter.remote && !locL.contains('remote') && !locL.contains('work from home')) return false;
        if (filter == JobFilter.fullTime && isIntern) return false;
        if (filter == JobFilter.internship && !isIntern) return false;
        
        return true;
      }).toList();

      // Filter Scraped
      final filteredScraped = _allScrapedJobs.where((job) {
        final titleL = job.title.toLowerCase();
        final locL = job.location.toLowerCase();
        final isIntern = titleL.contains('intern') || job.source == JobSource.internshala;
        
        if (filter == JobFilter.direct) return false;
        if (filter == JobFilter.remote && !locL.contains('remote') && !locL.contains('work from home')) return false;
        if (filter == JobFilter.fullTime && isIntern) return false; // Exclude internships from full-time
        if (filter == JobFilter.internship && !isIntern) return false;
        
        return true;
      }).toList();

      _displayedJobs.addAll(filteredSupabase);
      _displayedJobs.addAll(filteredScraped);
    });
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<void> _openExternalJob(String url) async {
    HapticFeedback.lightImpact();
    final uri = Uri.parse(url);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open job link.')),
        );
      }
    }
  }
  
  void _openDirectJob(Map<String, dynamic> job) {
    HapticFeedback.lightImpact();
    Navigator.push(context, MaterialPageRoute(builder: (_) => JobDetailPage(job: job)));
  }

  void _toggleBookmark(String jobId) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_bookmarkedJobIds.contains(jobId)) {
        _bookmarkedJobIds.remove(jobId);
        _showSnack('Removed from saved jobs', null);
      } else {
        _bookmarkedJobIds.add(jobId);
        _showSnack('Job saved!', AppColors.success);
      }
    });
  }

  void _showSnack(String msg, Color? color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      duration: const Duration(seconds: 1),
      behavior: SnackBarBehavior.floating,
      backgroundColor: color,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  // ── UI ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(isDark),
            Expanded(child: _buildBody(isDark)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Explore Opportunities',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: _useResumeSearch,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(LucideIcons.sparkles, size: 14, color: AppColors.primary),
                            SizedBox(width: 6),
                            Text('Match My Resume', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Row(children: [
                GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ColdDmGeneratorPage())),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                    decoration: BoxDecoration(
                      gradient: AppColors.purpleGradient,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [BoxShadow(color: AppColors.accentPurple.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4))],
                    ),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(LucideIcons.send, color: Colors.white, size: 14),
                      SizedBox(width: 4),
                      Text('DM', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                    ]),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MapJobsPage())),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                    decoration: BoxDecoration(
                      gradient: AppColors.tealGradient,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [BoxShadow(color: AppColors.accent.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4))],
                    ),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(LucideIcons.mapPin, color: Colors.white, size: 14),
                      SizedBox(width: 4),
                      Text('Map', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                    ]),
                  ),
                ),
              ]),
            ],
          ),
          const SizedBox(height: 16),
          // Search field
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.05) : AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
            ),
            child: Row(children: [
              const Icon(LucideIcons.search, color: AppColors.primary, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onSubmitted: (_) => _performSearch(),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Search roles, skills...',
                    hintStyle: TextStyle(color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
                  ),
                ),
              ),
              GestureDetector(
                onTap: _performSearch,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(12)),
                  child: const Icon(LucideIcons.arrowRight, color: Colors.white, size: 18),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 16),
          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: JobFilter.values.map((f) {
                return Padding(
                  padding: EdgeInsets.only(right: f == JobFilter.values.last ? 0 : 8),
                  child: _FilterChip(
                    filter: f,
                    isSelected: _activeFilter == f,
                    count: _activeFilter == f ? null : _countFor(f),
                    onTap: () {
                      HapticFeedback.selectionClick();
                      _applyFilter(f);
                    },
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  int _countFor(JobFilter f) {
    int count = 0;
    // Count Supabase
    count += _allSupabaseJobs.where((job) {
      final titleL = (job['title'] ?? '').toString().toLowerCase();
      final locL = (job['location'] ?? '').toString().toLowerCase();
      final typeL = (job['job_type'] ?? '').toString().toLowerCase();
      final isIntern = titleL.contains('intern') || typeL.contains('intern');
      if (f == JobFilter.external) return false;
      if (f == JobFilter.remote && !locL.contains('remote') && !locL.contains('work from home')) return false;
      if (f == JobFilter.fullTime && isIntern) return false;
      if (f == JobFilter.internship && !isIntern) return false;
      return true;
    }).length;
    // Count Scraped
    count += _allScrapedJobs.where((job) {
      final titleL = job.title.toLowerCase();
      final locL = job.location.toLowerCase();
      final isIntern = titleL.contains('intern') || job.source == JobSource.internshala;
      if (f == JobFilter.direct) return false;
      if (f == JobFilter.remote && !locL.contains('remote') && !locL.contains('work from home')) return false;
      if (f == JobFilter.fullTime && isIntern) return false;
      if (f == JobFilter.internship && !isIntern) return false;
      return true;
    }).length;
    return count;
  }

  Widget _buildBody(bool isDark) {
    if (_isLoading) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const CircularProgressIndicator(color: AppColors.primary),
          const SizedBox(height: 16),
          Text('Scanning Direct Jobs & Externals...',
              style: TextStyle(color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight, fontWeight: FontWeight.w500)),
        ]),
      );
    }

    if (_errorMessage != null && _displayedJobs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: const Icon(LucideIcons.alertCircle, color: AppColors.error, size: 40),
            ),
            const SizedBox(height: 24),
            Text('Search Failed', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(_errorMessage!, textAlign: TextAlign.center,
                style: TextStyle(color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight)),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _performSearch,
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              icon: const Icon(LucideIcons.refreshCcw, size: 18),
              label: const Text('Try Again', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ]),
        ),
      );
    }

    if (_displayedJobs.isEmpty) {
      final hasAny = _allSupabaseJobs.isNotEmpty || _allScrapedJobs.isNotEmpty;
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(LucideIcons.searchX, color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight, size: 64),
          const SizedBox(height: 16),
          Text(hasAny ? 'No ${_activeFilter.label} jobs found' : 'No jobs found',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(hasAny ? 'Try a different filter or search term' : 'Try adjusting your search',
              style: const TextStyle(color: AppColors.textSecondaryLight)),
          if (hasAny) ...[
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => _applyFilter(JobFilter.all),
              child: const Text('Show all jobs'),
            ),
          ]
        ]),
      );
    }

    return RefreshIndicator(
      onRefresh: _performSearch,
      color: AppColors.primary,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
        physics: const BouncingScrollPhysics(),
        itemCount: _displayedJobs.length,
        separatorBuilder: (_, _) => const SizedBox(height: 16),
        itemBuilder: (_, i) {
          final jobItem = _displayedJobs[i];
          if (jobItem is JobListingModel) {
            return _ExternalJobCard(
              job: jobItem,
              isDark: isDark,
              isBookmarked: _bookmarkedJobIds.contains(jobItem.id),
              onTapApply: () => _openExternalJob(jobItem.sourceUrl),
              onTapDetails: () => _openExternalJob(jobItem.sourceUrl),
              onTapBookmark: () => _toggleBookmark(jobItem.id),
            );
          } else if (jobItem is Map<String, dynamic>) {
            return _DirectJobCard(
              job: jobItem,
              isDark: isDark,
              isBookmarked: _bookmarkedJobIds.contains(jobItem['id']),
              onTapApply: () => _openDirectJob(jobItem),
              onTapDetails: () => _openDirectJob(jobItem),
              onTapBookmark: () => _toggleBookmark(jobItem['id']),
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }
}

// ── Filter chip widget ───────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final JobFilter filter;
  final bool isSelected;
  final int? count;
  final VoidCallback onTap;

  const _FilterChip({required this.filter, required this.isSelected, this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = filter.color ?? AppColors.primary;
    final bg = isSelected ? color : color.withValues(alpha: 0.08);
    final fg = isSelected ? Colors.white : color;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: isSelected ? 0 : 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(filter.label, style: TextStyle(color: fg, fontWeight: FontWeight.bold, fontSize: 13)),
            if (count != null && count! > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                child: Text('$count', style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Direct Job (Supabase) Card ───────────────────────────────────────────────

class _DirectJobCard extends StatelessWidget {
  final Map<String, dynamic> job;
  final bool isDark;
  final bool isBookmarked;
  final VoidCallback onTapApply;
  final VoidCallback onTapDetails;
  final VoidCallback onTapBookmark;

  const _DirectJobCard({
    required this.job,
    required this.isDark,
    required this.isBookmarked,
    required this.onTapApply,
    required this.onTapDetails,
    required this.onTapBookmark,
  });

  @override
  Widget build(BuildContext context) {
    final aiEnabled = job['ai_screening_enabled'] == true;
    final companyName = job['companies']?['name'] ?? 'Company';
    
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)), // highlight direct jobs
        boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.08), blurRadius: 20, offset: const Offset(0, 5))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTapDetails,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Direct Job Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(color: const Color(0xFF22C55E).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                      child: const Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(LucideIcons.checkCircle, size: 14, color: Color(0xFF16A34A)),
                        SizedBox(width: 6),
                        Text('Direct on Hustlr', style: TextStyle(color: Color(0xFF16A34A), fontWeight: FontWeight.bold, fontSize: 12)),
                      ]),
                    ),
                    const Spacer(),
                    if (aiEnabled)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                        ),
                        child: const Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(LucideIcons.bot, size: 12, color: AppColors.primary),
                          SizedBox(width: 4),
                          Text('AI Screening', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12)),
                        ]),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(job['title'] ?? 'Role',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, height: 1.2)),
                const SizedBox(height: 6),
                Text('$companyName • ${job['location'] ?? 'Remote'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                        fontSize: 14,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 16),
                Wrap(spacing: 12, runSpacing: 8, children: [
                  if (job['salary_range'] != null) _Tag(icon: LucideIcons.indianRupee, text: job['salary_range'], isDark: isDark),
                  if (job['experience_level'] != null) _Tag(icon: LucideIcons.briefcase, text: job['experience_level'], isDark: isDark),
                  _Tag(icon: LucideIcons.clock, text: job['job_type'] ?? 'Full-Time', isDark: isDark),
                ]),
                const SizedBox(height: 20),
                Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onTapDetails,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: isDark ? Colors.white : Colors.black87,
                        side: BorderSide(color: isDark ? Colors.white12 : Colors.black12),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('View Details', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 4))],
                      ),
                      child: ElevatedButton(
                        onPressed: onTapApply,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(aiEnabled ? LucideIcons.bot : LucideIcons.send, size: 16),
                            const SizedBox(width: 6),
                            Text(aiEnabled ? 'Apply via AI' : 'Apply Now', style: const TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  InkWell(
                    onTap: onTapBookmark,
                    borderRadius: BorderRadius.circular(12),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isBookmarked ? AppColors.primary.withValues(alpha: 0.12) : Colors.transparent,
                        border: Border.all(color: isBookmarked ? AppColors.primary : (isDark ? Colors.white12 : Colors.black12)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        LucideIcons.bookmark,
                        color: isBookmarked ? AppColors.primary : (isDark ? Colors.white70 : Colors.black54),
                        size: 20,
                      ),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


// ── External Job (Scraped) Card ──────────────────────────────────────────────

class _ExternalJobCard extends StatelessWidget {
  final JobListingModel job;
  final bool isDark;
  final bool isBookmarked;
  final VoidCallback onTapApply;
  final VoidCallback onTapDetails;
  final VoidCallback onTapBookmark;

  const _ExternalJobCard({
    required this.job,
    required this.isDark,
    required this.isBookmarked,
    required this.onTapApply,
    required this.onTapDetails,
    required this.onTapBookmark,
  });

  @override
  Widget build(BuildContext context) {
    final matchPct = (job.matchScore * 100).toInt();
    final matchColor = matchPct >= 80 ? AppColors.success : matchPct >= 40 ? AppColors.warning : AppColors.error;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTapDetails,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildScamBanner(),
                Row(
                  children: [
                    _SourceBadge(source: job.source),
                    const Spacer(),
                    _ScamBadge(trustScore: job.trustScore, scamPercentage: job.scamPercentage),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: matchColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: matchColor.withValues(alpha: 0.3)),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(LucideIcons.zap, size: 12, color: matchColor),
                        const SizedBox(width: 4),
                        Text('$matchPct% Match',
                            style: TextStyle(color: matchColor, fontWeight: FontWeight.bold, fontSize: 12)),
                      ]),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(job.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, height: 1.2)),
                const SizedBox(height: 6),
                Text('${job.company} • ${job.location}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                        fontSize: 14,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 16),
                Wrap(spacing: 12, runSpacing: 8, children: [
                  if (job.salaryRange != null) _Tag(icon: LucideIcons.indianRupee, text: job.salaryRange!, isDark: isDark),
                  if (job.experienceRequired != null) _Tag(icon: LucideIcons.briefcase, text: job.experienceRequired!, isDark: isDark),
                  _Tag(
                      icon: LucideIcons.clock,
                      text: job.postedAt != null ? _timeAgo(job.postedAt!) : 'Active',
                      isDark: isDark),
                ]),
                const SizedBox(height: 20),
                Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onTapDetails,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: isDark ? Colors.white : Colors.black87,
                        side: BorderSide(color: isDark ? Colors.white12 : Colors.black12),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('View Details', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: AppColors.tealGradient, // different color for external applies
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [BoxShadow(color: AppColors.accent.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 4))],
                      ),
                      child: ElevatedButton(
                        onPressed: onTapApply,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(LucideIcons.externalLink, size: 16),
                            SizedBox(width: 6),
                            Text('Apply Externally', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  InkWell(
                    onTap: onTapBookmark,
                    borderRadius: BorderRadius.circular(12),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isBookmarked ? AppColors.primary.withValues(alpha: 0.12) : Colors.transparent,
                        border: Border.all(color: isBookmarked ? AppColors.primary : (isDark ? Colors.white12 : Colors.black12)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        LucideIcons.bookmark,
                        color: isBookmarked ? AppColors.primary : (isDark ? Colors.white70 : Colors.black54),
                        size: 20,
                      ),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScamBanner() {
    if (job.trustScore == TrustScore.verified) return const SizedBox.shrink();
    final isFlagged = job.trustScore == TrustScore.flagged;
    final color = isFlagged ? AppColors.error : AppColors.warning;
    final headline = isFlagged ? 'High Risk: Potential Scam' : 'Caution: Suspicious Listing';
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(isFlagged ? LucideIcons.shieldAlert : LucideIcons.alertTriangle, size: 16, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Text(headline,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
            ),
          ]),
          if (job.flagReasons.isNotEmpty) ...[
            const SizedBox(height: 6),
            ...job.flagReasons.take(2).map((reason) => Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(LucideIcons.dot, size: 14, color: color.withValues(alpha: 0.8)),
                const SizedBox(width: 2),
                Expanded(
                  child: Text(reason,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: color.withValues(alpha: 0.9), height: 1.4)),
                ),
              ]),
            )),
            if (job.flagReasons.length > 2)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('+${job.flagReasons.length - 2} more reasons',
                    style: TextStyle(fontSize: 11, color: color.withValues(alpha: 0.7), fontStyle: FontStyle.italic)),
              ),
          ],
        ],
      ),
    );
  }

  String _timeAgo(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }
}

// ── Shared Badges ─────────────────────────────────────────────────────────────

class _ScamBadge extends StatelessWidget {
  final TrustScore trustScore;
  final int scamPercentage;
  const _ScamBadge({required this.trustScore, required this.scamPercentage});

  @override
  Widget build(BuildContext context) {
    final (Color color, IconData icon, String label) = switch (trustScore) {
      TrustScore.verified => (const Color(0xFF22C55E), LucideIcons.shieldCheck, 'Safe'),
      TrustScore.caution  => (const Color(0xFFF59E0B), LucideIcons.shieldAlert, 'Caution'),
      TrustScore.flagged  => (const Color(0xFFEF4444), LucideIcons.shieldOff, 'Scam Risk'),
    };

    final percentageText = trustScore == TrustScore.verified ? '' : ' $scamPercentage%';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text('$label$percentageText', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11)),
      ]),
    );
  }
}

class _SourceBadge extends StatelessWidget {
  final JobSource source;
  const _SourceBadge({required this.source});

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg, IconData icon, String label) = switch (source) {
      JobSource.linkedin    => (const Color(0xFF0A66C2).withValues(alpha: 0.15), const Color(0xFF0A66C2), LucideIcons.linkedin, 'LinkedIn'),
      JobSource.naukri      => (Colors.green.withValues(alpha: 0.15), Colors.green.shade700, LucideIcons.briefcase, 'Naukri'),
      JobSource.instahyre   => (Colors.deepPurple.withValues(alpha: 0.15), Colors.deepPurple, LucideIcons.rocket, 'Instahyre'),
      JobSource.internshala => (Colors.orange.withValues(alpha: 0.15), Colors.orange.shade700, LucideIcons.graduationCap, 'Internshala'),
      JobSource.shine       => (Colors.teal.withValues(alpha: 0.15), Colors.teal.shade700, LucideIcons.sparkles, 'Shine'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: fg),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(color: fg, fontWeight: FontWeight.bold, fontSize: 12)),
      ]),
    );
  }
}

class _Tag extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool isDark;
  const _Tag({required this.icon, required this.text, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final color = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 14, color: color),
      const SizedBox(width: 6),
      Text(text, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w500)),
    ]);
  }
}
 