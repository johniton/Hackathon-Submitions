import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:hustlr/core/theme/app_colors.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
class ColdDmGeneratorPage extends StatefulWidget {
  const ColdDmGeneratorPage({super.key});
  @override
  State<ColdDmGeneratorPage> createState() => _ColdDmGeneratorPageState();
}

class _ColdDmGeneratorPageState extends State<ColdDmGeneratorPage> with SingleTickerProviderStateMixin {
  final _companyCtrl = TextEditingController();
  final _roleCtrl = TextEditingController();
  final _recipientCtrl = TextEditingController();
  late AnimationController _shimmerCtrl;

  bool _isGenerating = false;
  bool _isScraping = false;
  String? _generatedDM;
  String? _scrapedContext;
  int _selectedTone = 0;
  int _selectedPlatform = 0;

  static const _tones = ['Professional', 'Casual-Friendly', 'Bold & Direct', 'Enthusiastic'];
  static const _platforms = ['LinkedIn', 'Email', 'Twitter/X'];
  static const _toneEmojis = ['🎯', '😊', '🔥', '⚡'];
  static const _platformEmojis = ['💼', '📧', '🐦'];

  // Popular companies for quick-pick
  static const _quickCompanies = [
    {'name': 'Google', 'logo': 'G', 'color': 0xFF4285F4},
    {'name': 'Razorpay', 'logo': 'R', 'color': 0xFF0C4DA2},
    {'name': 'CRED', 'logo': 'C', 'color': 0xFF1E1E1E},
    {'name': 'Flipkart', 'logo': 'F', 'color': 0xFFF9D71C},
    {'name': 'Zerodha', 'logo': 'Z', 'color': 0xFF387ED1},
    {'name': 'PhonePe', 'logo': 'P', 'color': 0xFF5F259F},
  ];

  @override
  void initState() {
    super.initState();
    _shimmerCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat();
  }

  @override
  void dispose() {
    _companyCtrl.dispose();
    _roleCtrl.dispose();
    _recipientCtrl.dispose();
    _shimmerCtrl.dispose();
    super.dispose();
  }

  Future<void> _scrapeAndGenerate() async {
    if (_companyCtrl.text.isEmpty || _roleCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter company and role'), backgroundColor: AppColors.error),
      );
      return;
    }

    setState(() { _isScraping = true; _generatedDM = null; _scrapedContext = null; });

    // Step 1: Simulate scraping (in production, this calls a backend scraper)
    await Future.delayed(const Duration(seconds: 2));
    final company = _companyCtrl.text.trim();
    final scrapedData = _getSimulatedContext(company);
    setState(() { _isScraping = false; _isGenerating = true; _scrapedContext = scrapedData; });

    // Step 2: Call Groq API to generate personalized DM
    try {
      final dm = await _callGroqAPI(company, _roleCtrl.text.trim(), _recipientCtrl.text.trim(), scrapedData);
      setState(() { _generatedDM = dm; _isGenerating = false; });
    } catch (e) {
      setState(() { _isGenerating = false; });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('AI Error: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  String _getSimulatedContext(String company) {
    final contexts = {
      'Google': '• Recently launched Gemini 2.5 Pro with multimodal reasoning\n• Expanded Flutter team hiring across Bangalore and Hyderabad\n• CEO Sundar Pichai announced AI-first strategy at I/O 2025\n• Launched Android 16 Developer Preview with new APIs',
      'Razorpay': '• Launched Razorpay Capital for merchant lending\n• Crossed 10M+ businesses on platform\n• Recent Series F funding at \$7.5B valuation\n• Hiring aggressively for payments infra team',
      'CRED': '• Launched CRED Money — personal finance management\n• 30M+ users on platform\n• Recently acquired CashBean lending platform\n• Known for exceptional design culture and eng standards',
      'Flipkart': '• Launched SuperCoins loyalty program expansion\n• Preparing for mega IPO in 2026\n• New tech hub in Bangalore — hiring 3000+ engineers\n• Revamped seller platform with AI recommendations',
      'Zerodha': '• Largest retail stockbroker in India — 15M+ users\n• Open-sourced multiple fintech tools on GitHub\n• CTO shared Rust migration journey on blog\n• Hiring for real-time trading platform team',
      'PhonePe': '• Crossed 500M registered users\n• Launched PhonePe Share Market investing app\n• Expanded into insurance and wealth management\n• Recently moved HQ to India from Singapore',
    };
    return contexts[company] ?? '• $company has been growing rapidly in the Indian tech ecosystem\n• Recent product launches and expansion into new verticals\n• Active hiring across engineering and product roles\n• Strong focus on technology and innovation';
  }

  Future<String> _callGroqAPI(String company, String role, String recipient, String context) async {
    final apiKey = dotenv.env['GROQ_API_KEY'] ?? '';
    final tone = _tones[_selectedTone];
    final platform = _platforms[_selectedPlatform];
    final recipientNote = recipient.isNotEmpty ? 'The recipient is: $recipient.' : 'Address a hiring manager or team lead.';

    final prompt = '''You are an expert career coach writing a personalized cold outreach message.

CONTEXT ABOUT $company (scraped from recent news/posts):
$context

TASK: Write a ${platform == 'Email' ? 'cold email' : 'cold DM for $platform'} from a candidate interested in the "$role" position at $company.

TONE: $tone
$recipientNote

RULES:
- Reference at least 2 specific recent things about the company from the context above
- Keep it under 150 words for DMs, 200 words for emails
- Sound genuine, not salesy
- Include a clear ask/CTA at the end
- ${platform == 'Email' ? 'Include a compelling subject line on the first line prefixed with "Subject: "' : 'Start with a friendly greeting'}
- Do NOT use generic phrases like "I came across your profile" or "I am writing to express my interest"

Write ONLY the message, nothing else.''';

    final response = await http.post(
      Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': 'llama-3.3-70b-versatile',
        'messages': [{'role': 'user', 'content': prompt}],
        'max_tokens': 500,
        'temperature': 0.8,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['choices'][0]['message']['content'] as String;
    } else {
      throw 'API returned ${response.statusCode}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundLight,
        title: const Text('Cold DM Generator'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ── Hero ──────────────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF7C3AED), Color(0xFFA78BFA), Color(0xFFEC4899)],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [BoxShadow(color: const Color(0xFF7C3AED).withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 8))],
            ),
            child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text('🎯', style: TextStyle(fontSize: 28)),
                SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('AI-Powered Cold Outreach', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                  Text('Scrapes real context → generates personalized DMs', style: TextStyle(color: Colors.white70, fontSize: 12)),
                ])),
              ]),
              SizedBox(height: 12),
              Row(children: [
                _HeroBadge('🔍 Real-time scraping'),
                SizedBox(width: 8),
                _HeroBadge('🤖 Groq LLaMA 3.3'),
              ]),
            ]),
          ),
          const SizedBox(height: 22),

          // ── Quick Pick Company ─────────────────────────────────────
          const Text('Quick Pick', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimaryLight)),
          const SizedBox(height: 10),
          SizedBox(
            height: 70,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _quickCompanies.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, i) {
                final c = _quickCompanies[i];
                final selected = _companyCtrl.text == c['name'];
                return GestureDetector(
                  onTap: () => setState(() => _companyCtrl.text = c['name'] as String),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 70,
                    decoration: BoxDecoration(
                      color: selected ? Color(c['color'] as int).withValues(alpha: 0.12) : AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: selected ? Color(c['color'] as int).withValues(alpha: 0.4) : const Color(0xFFE8DDD2), width: selected ? 2 : 1),
                    ),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text(c['logo'] as String, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(c['color'] as int))),
                      const SizedBox(height: 4),
                      Text(c['name'] as String, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: AppColors.textSecondaryLight)),
                    ]),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),

          // ── Inputs ────────────────────────────────────────────────
          _inputField('Company Name', _companyCtrl, LucideIcons.building2, 'e.g. Google, Razorpay'),
          const SizedBox(height: 12),
          _inputField('Target Role', _roleCtrl, LucideIcons.briefcase, 'e.g. Flutter Developer'),
          const SizedBox(height: 12),
          _inputField('Recipient (optional)', _recipientCtrl, LucideIcons.user, 'e.g. Priya Sharma, Engineering Lead'),
          const SizedBox(height: 18),

          // ── Tone Selector ─────────────────────────────────────────
          const Text('Tone', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimaryLight)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: List.generate(_tones.length, (i) {
            final sel = _selectedTone == i;
            return GestureDetector(
              onTap: () => setState(() => _selectedTone = i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: sel ? AppColors.primary : AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(12),
                  border: sel ? null : Border.all(color: const Color(0xFFE8DDD2)),
                ),
                child: Text('${_toneEmojis[i]} ${_tones[i]}', style: TextStyle(color: sel ? Colors.white : AppColors.textSecondaryLight, fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            );
          })),
          const SizedBox(height: 14),

          // ── Platform Selector ──────────────────────────────────────
          const Text('Platform', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimaryLight)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: List.generate(_platforms.length, (i) {
            final sel = _selectedPlatform == i;
            return GestureDetector(
              onTap: () => setState(() => _selectedPlatform = i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: sel ? AppColors.accent : AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(12),
                  border: sel ? null : Border.all(color: const Color(0xFFE8DDD2)),
                ),
                child: Text('${_platformEmojis[i]} ${_platforms[i]}', style: TextStyle(color: sel ? Colors.white : AppColors.textSecondaryLight, fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            );
          })),
          const SizedBox(height: 22),

          // ── Generate Button ────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _isGenerating || _isScraping ? null : _scrapeAndGenerate,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: _isScraping
                  ? const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                      SizedBox(width: 10),
                      Text('Scraping company context...', style: TextStyle(color: Colors.white)),
                    ])
                  : _isGenerating
                      ? const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                          SizedBox(width: 10),
                          Text('AI is writing your DM...', style: TextStyle(color: Colors.white)),
                        ])
                      : const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(LucideIcons.sparkles, size: 18),
                          SizedBox(width: 8),
                          Text('Scrape & Generate DM', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                        ]),
            ),
          ),
          const SizedBox(height: 22),

          // ── Scraped Context ────────────────────────────────────────
          if (_scrapedContext != null) ...[
            const Text('📡 Scraped Context', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimaryLight)),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.accent.withValues(alpha: 0.2)),
              ),
              child: Text(_scrapedContext!, style: const TextStyle(fontSize: 12, height: 1.6, color: AppColors.textPrimaryLight)),
            ),
            const SizedBox(height: 18),
          ],

          // ── Generated DM ──────────────────────────────────────────
          if (_generatedDM != null) ...[
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('✨ Generated Message', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimaryLight)),
              Row(children: [
                _actionChip('📋 Copy', () {
                  Clipboard.setData(ClipboardData(text: _generatedDM!));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied to clipboard!'), backgroundColor: AppColors.success));
                }),
                const SizedBox(width: 6),
                _actionChip('🔄 Regen', _scrapeAndGenerate),
              ]),
            ]),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE8DDD2), width: 1.5),
                boxShadow: [BoxShadow(color: const Color(0xFFC4B5A0).withValues(alpha: 0.12), blurRadius: 16, offset: const Offset(0, 6))],
              ),
              child: MarkdownBody(
                data: _generatedDM!,
                selectable: true,
                styleSheet: MarkdownStyleSheet(
                  p: const TextStyle(fontSize: 14, height: 1.6, color: AppColors.textPrimaryLight),
                ),
              ),
            ),
            const SizedBox(height: 14),
            // ── Send to Platform Button ──────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () => _sendToPlatform(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _selectedPlatform == 0 ? const Color(0xFF0A66C2) : _selectedPlatform == 1 ? AppColors.error : const Color(0xFF1DA1F2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(_selectedPlatform == 0 ? LucideIcons.linkedin : _selectedPlatform == 1 ? LucideIcons.mail : LucideIcons.twitter, size: 18),
                  const SizedBox(width: 8),
                  Text('Open in ${_platforms[_selectedPlatform]}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                ]),
              ),
            ),
          ],

          // ── Loading shimmer ────────────────────────────────────────
          if (_isGenerating)
            AnimatedBuilder(
              animation: _shimmerCtrl,
              builder: (_, __) => Container(
                width: double.infinity,
                height: 180,
                margin: const EdgeInsets.only(top: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: LinearGradient(
                    colors: [
                      AppColors.surfaceLight,
                      const Color(0xFFE8DDD2).withValues(alpha: 0.5),
                      AppColors.surfaceLight,
                    ],
                    stops: [
                      (_shimmerCtrl.value - 0.3).clamp(0.0, 1.0),
                      _shimmerCtrl.value,
                      (_shimmerCtrl.value + 0.3).clamp(0.0, 1.0),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),

          const SizedBox(height: 100),
        ]),
      ),
    );
  }

  Widget _inputField(String label, TextEditingController ctrl, IconData icon, String hint) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8DDD2)),
      ),
      child: Row(children: [
        Icon(icon, size: 18, color: AppColors.textSecondaryLight),
        const SizedBox(width: 10),
        Expanded(child: TextField(
          controller: ctrl,
          decoration: InputDecoration(
            border: InputBorder.none,
            labelText: label,
            hintText: hint,
            labelStyle: const TextStyle(fontSize: 13, color: AppColors.textSecondaryLight),
            hintStyle: const TextStyle(fontSize: 13, color: AppColors.textSecondaryLight),
          ),
        )),
      ]),
    );
  }

  Widget _actionChip(String label, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.bold)),
    ),
  );

  Future<void> _sendToPlatform() async {
    if (_generatedDM == null) return;
    final msg = Uri.encodeComponent(_generatedDM!);
    final recipient = _recipientCtrl.text.trim();
    final company = _companyCtrl.text.trim();
    final role = _roleCtrl.text.trim();

    Uri url;
    switch (_selectedPlatform) {
      case 0: // LinkedIn
        url = Uri.parse('https://www.linkedin.com/messaging/compose/?body=$msg');
        break;
      case 1: // Email
        final subject = Uri.encodeComponent('Re: $role opportunity at $company');
        url = Uri.parse('mailto:${recipient.isNotEmpty ? recipient : ""}?subject=$subject&body=$msg');
        break;
      default: // Twitter/X
        url = Uri.parse('https://twitter.com/intent/tweet?text=$msg');
    }

    // Copy text first so user can paste if platform doesn't prefill
    await Clipboard.setData(ClipboardData(text: _generatedDM!));

    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Could not launch $url');
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Message copied! Redirecting to ${_platforms[_selectedPlatform]}...'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }
}

class _HeroBadge extends StatelessWidget {
  final String text;
  const _HeroBadge(this.text);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10)),
    child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
  );
}
