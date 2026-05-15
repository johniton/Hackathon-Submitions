import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:hustlr/core/theme/app_colors.dart';
import 'package:hustlr/features/ai_interview/data/interview_models.dart';
import 'package:hustlr/features/ai_interview/presentation/pages/interview_live_page.dart';

class InterviewSetupPage extends StatefulWidget {
  const InterviewSetupPage({super.key});

  @override
  State<InterviewSetupPage> createState() => _InterviewSetupPageState();
}

class _InterviewSetupPageState extends State<InterviewSetupPage> with SingleTickerProviderStateMixin {
  final _roleController = TextEditingController();
  final _companiesController = TextEditingController();
  String _interviewType = 'MIXED';
  String _difficulty = 'MID';
  bool _isStarting = false;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  final _roleSuggestions = [
    'Flutter Engineer',
    'Backend Developer',
    'Full Stack Dev',
    'ML Engineer',
    'DevOps Engineer',
    'iOS Developer',
    'Product Manager',
    'Data Scientist',
  ];

  final _companySuggestions = [
    'Google', 'Microsoft', 'Amazon', 'Swiggy', 'Zepto',
    'Flipkart', 'PhonePe', 'Razorpay', 'CRED', 'Uber',
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _roleController.dispose();
    _companiesController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  List<String> get _parsedCompanies {
    return _companiesController.text
        .split(RegExp(r'[,;]'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  void _startInterview() {
    if (_roleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a job role'), backgroundColor: AppColors.error),
      );
      return;
    }

    final setup = InterviewSetup(
      jobRole: _roleController.text.trim(),
      targetCompanies: _parsedCompanies,
      interviewType: _interviewType,
      difficulty: _difficulty,
    );

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => InterviewLivePage(setup: setup)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : const Color(0xFF0F172A),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // Header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            width: 40, height: 40,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(LucideIcons.arrowLeft, color: Colors.white70, size: 20),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('AI Mock Interview', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 2),
                              Text('Configure your session', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13)),
                            ],
                          ),
                        ),
                        AnimatedBuilder(
                          animation: _pulseAnimation,
                          builder: (_, __) => Opacity(
                            opacity: _pulseAnimation.value,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                gradient: AppColors.primaryGradient,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(LucideIcons.sparkles, color: Colors.white, size: 12),
                                  SizedBox(width: 4),
                                  Text('AI', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                  ],
                ),
              ),
            ),

            // Job Role
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionLabel('JOB ROLE'),
                    const SizedBox(height: 8),
                    _textField(
                      controller: _roleController,
                      hint: 'e.g. Flutter Engineer',
                      icon: LucideIcons.briefcase,
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _roleSuggestions.map((r) => _suggestionChip(r, () {
                        _roleController.text = r;
                        setState(() {});
                      })).toList(),
                    ),
                    const SizedBox(height: 28),
                  ],
                ),
              ),
            ),

            // Target Companies
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionLabel('TARGET COMPANIES'),
                    const SizedBox(height: 4),
                    Text('AI will research these companies for tailored questions',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 12)),
                    const SizedBox(height: 8),
                    _textField(
                      controller: _companiesController,
                      hint: 'e.g. Google, Swiggy, Zepto',
                      icon: LucideIcons.building2,
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _companySuggestions.map((c) => _suggestionChip(c, () {
                        final current = _companiesController.text;
                        if (current.isEmpty) {
                          _companiesController.text = c;
                        } else if (!current.contains(c)) {
                          _companiesController.text = '$current, $c';
                        }
                        setState(() {});
                      })).toList(),
                    ),
                    const SizedBox(height: 28),
                  ],
                ),
              ),
            ),

            // Interview Type
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionLabel('INTERVIEW TYPE'),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _typeChip('MIXED', LucideIcons.layers, 'Mixed'),
                        const SizedBox(width: 10),
                        _typeChip('TECHNICAL', LucideIcons.code2, 'Technical'),
                        const SizedBox(width: 10),
                        _typeChip('HR', LucideIcons.users, 'HR'),
                      ],
                    ),
                    const SizedBox(height: 28),
                  ],
                ),
              ),
            ),

            // Difficulty
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionLabel('DIFFICULTY LEVEL'),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _diffChip('JUNIOR', 'Junior', '0-2 yrs'),
                        const SizedBox(width: 10),
                        _diffChip('MID', 'Mid', '2-5 yrs'),
                        const SizedBox(width: 10),
                        _diffChip('SENIOR', 'Senior', '5+ yrs'),
                      ],
                    ),
                    const SizedBox(height: 28),
                  ],
                ),
              ),
            ),

            // Preview Card
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.primary.withValues(alpha: 0.15), AppColors.accentPurple.withValues(alpha: 0.08)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(LucideIcons.sparkles, color: AppColors.primaryLight, size: 16),
                          const SizedBox(width: 6),
                          const Text('What AI will do', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _previewRow(LucideIcons.search, 'Research ${_parsedCompanies.isEmpty ? "companies" : _parsedCompanies.join(", ")}'),
                      _previewRow(LucideIcons.messageCircle, 'Ask 5–12 adaptive ${_interviewType.toLowerCase()} questions'),
                      _previewRow(LucideIcons.mic, 'Transcribe your spoken answers in real-time'),
                      _previewRow(LucideIcons.barChart2, 'Score on relevance, clarity, completeness & confidence'),
                      _previewRow(LucideIcons.trophy, 'Give you a detailed performance report'),
                    ],
                  ),
                ),
              ),
            ),

            // CTA Button
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 40),
                child: GestureDetector(
                  onTap: _isStarting ? null : _startInterview,
                  child: Container(
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(color: AppColors.primary.withValues(alpha: 0.4), blurRadius: 20, offset: const Offset(0, 8)),
                      ],
                    ),
                    child: Center(
                      child: _isStarting
                          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                          : const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(LucideIcons.play, color: Colors.white, size: 20),
                                SizedBox(width: 10),
                                Text('Begin Interview', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                              ],
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.4),
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 2,
      ),
    );
  }

  Widget _textField({required TextEditingController controller, required String hint, required IconData icon}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: TextField(
        controller: controller,
        style: const TextStyle(color: Colors.white, fontSize: 15),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: Colors.white38, size: 20),
          hintText: hint,
          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.25)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        onChanged: (_) => setState(() {}),
      ),
    );
  }

  Widget _suggestionChip(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 12, fontWeight: FontWeight.w500)),
      ),
    );
  }

  Widget _typeChip(String value, IconData icon, String label) {
    final selected = _interviewType == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _interviewType = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            gradient: selected ? AppColors.primaryGradient : null,
            color: selected ? null : Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: selected ? Colors.transparent : Colors.white.withValues(alpha: 0.08)),
          ),
          child: Column(
            children: [
              Icon(icon, color: selected ? Colors.white : Colors.white38, size: 22),
              const SizedBox(height: 6),
              Text(label, style: TextStyle(color: selected ? Colors.white : Colors.white54, fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _diffChip(String value, String label, String sub) {
    final selected = _difficulty == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _difficulty = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            gradient: selected ? AppColors.tealGradient : null,
            color: selected ? null : Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: selected ? Colors.transparent : Colors.white.withValues(alpha: 0.08)),
          ),
          child: Column(
            children: [
              Text(label, style: TextStyle(color: selected ? Colors.white : Colors.white54, fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text(sub, style: TextStyle(color: selected ? Colors.white70 : Colors.white30, fontSize: 10)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _previewRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primaryLight, size: 14),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12))),
        ],
      ),
    );
  }
}
