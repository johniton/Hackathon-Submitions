import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:hustlr/core/theme/app_colors.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:url_launcher/url_launcher.dart';

class AiTechFeedPage extends StatefulWidget {
  const AiTechFeedPage({super.key});
  @override
  State<AiTechFeedPage> createState() => _AiTechFeedPageState();
}

class _AiTechFeedPageState extends State<AiTechFeedPage> {
  int _activeDomain = 0;
  bool _loading = true;
  bool _digestLoading = false;
  String? _digestText;

  static const _domains = ['All', 'Dev.to', 'Hacker News', 'GitHub', 'TechCrunch', 'Vercel'];
  static const _domainIcons = [LucideIcons.globe, LucideIcons.code2, LucideIcons.flame, LucideIcons.github, LucideIcons.newspaper, LucideIcons.triangle];
  static const _domainColors = [Color(0xFF6366F1), Color(0xFF10B981), Color(0xFFFF6600), Color(0xFF24292F), Color(0xFF0A9E01), Color(0xFF000000)];

  static const _rssSources = [
    {'url': 'https://dev.to/feed', 'name': 'Dev.to', 'cat': 'Dev.to'},
    {'url': 'https://hnrss.org/frontpage', 'name': 'Hacker News', 'cat': 'Hacker News'},
    {'url': 'https://github.blog/feed', 'name': 'GitHub', 'cat': 'GitHub'},
    {'url': 'https://feeds.feedburner.com/TechCrunch', 'name': 'TechCrunch', 'cat': 'TechCrunch'},
    {'url': 'https://vercel.com/atom', 'name': 'Vercel', 'cat': 'Vercel'},
  ];

  List<Map<String, String>> _allArticles = [];

  @override
  void initState() { super.initState(); _fetchAllFeeds(); }

  String _proxy(String url) => kIsWeb ? 'https://api.allorigins.win/raw?url=${Uri.encodeComponent(url)}' : url;

  Future<void> _fetchAllFeeds() async {
    setState(() { _loading = true; });
    final List<Map<String, String>> articles = [];
    final futures = _rssSources.map((src) async {
      try {
        final resp = await http.get(Uri.parse(_proxy(src['url']!))).timeout(const Duration(seconds: 12));
        if (resp.statusCode == 200) articles.addAll(_parseFeed(resp.body, src['name']!, src['cat']!));
      } catch (e) { debugPrint('RSS fail ${src['name']}: $e'); }
    });
    await Future.wait(futures);
    setState(() { _allArticles = articles; _loading = false; });
  }

  List<Map<String, String>> _parseFeed(String xml, String source, String cat) {
    final items = <Map<String, String>>[];
    // RSS <item> format
    final itemRx = RegExp(r'<item[^>]*>(.*?)</item>', dotAll: true);
    var matches = itemRx.allMatches(xml);
    if (matches.isNotEmpty) {
      for (final m in matches.take(10)) {
        final block = m.group(1) ?? '';
        final title = _tag(block, 'title');
        final link = _tag(block, 'link');
        final desc = _tag(block, 'description');
        final date = _tag(block, 'pubDate');
        if (title.isNotEmpty) items.add({'title': _clean(title), 'link': link.trim(), 'desc': _clean(desc).length > 180 ? '${_clean(desc).substring(0, 180)}…' : _clean(desc), 'date': date, 'source': source, 'cat': cat, 'time': _ago(date)});
      }
    } else {
      // Atom <entry> format
      final entryRx = RegExp(r'<entry[^>]*>(.*?)</entry>', dotAll: true);
      for (final m in entryRx.allMatches(xml).take(10)) {
        final block = m.group(1) ?? '';
        final title = _tag(block, 'title');
        final linkM = RegExp(r'<link[^>]*href="([^"]*)"').firstMatch(block);
        final link = linkM?.group(1) ?? _tag(block, 'link');
        final desc = _tag(block, 'summary').isNotEmpty ? _tag(block, 'summary') : _tag(block, 'content');
        final date = _tag(block, 'updated').isNotEmpty ? _tag(block, 'updated') : _tag(block, 'published');
        if (title.isNotEmpty) items.add({'title': _clean(title), 'link': link.trim(), 'desc': _clean(desc).length > 180 ? '${_clean(desc).substring(0, 180)}…' : _clean(desc), 'date': date, 'source': source, 'cat': cat, 'time': _ago(date)});
      }
    }
    return items;
  }

  String _tag(String xml, String t) {
    final cdata = RegExp('<$t[^>]*>\\s*<!\\[CDATA\\[(.+?)\\]\\]>\\s*</$t>', dotAll: true).firstMatch(xml);
    if (cdata != null) return cdata.group(1) ?? '';
    final plain = RegExp('<$t[^>]*>(.*?)</$t>', dotAll: true).firstMatch(xml);
    return plain?.group(1)?.trim() ?? '';
  }

  String _clean(String s) => s.replaceAll(RegExp(r'<[^>]+>'), '').replaceAll('&amp;', '&').replaceAll('&lt;', '<').replaceAll('&gt;', '>').replaceAll('&quot;', '"').replaceAll('&#39;', "'").replaceAll('&nbsp;', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();

  String _ago(String d) {
    try {
      DateTime? dt = DateTime.tryParse(d);
      if (dt == null) {
        const mo = {'Jan':1,'Feb':2,'Mar':3,'Apr':4,'May':5,'Jun':6,'Jul':7,'Aug':8,'Sep':9,'Oct':10,'Nov':11,'Dec':12};
        final p = d.replaceAll(',', '').split(RegExp(r'\s+'));
        if (p.length >= 5) {
          final tp = p[4].split(':');
          dt = DateTime.utc(int.parse(p[3]), mo[p[2]] ?? 1, int.parse(p[1]), int.parse(tp[0]), tp.length > 1 ? int.parse(tp[1]) : 0);
        }
      }
      if (dt == null) return '';
      final diff = DateTime.now().toUtc().difference(dt.toUtc());
      if (diff.inMinutes < 60) return '${diff.inMinutes}m';
      if (diff.inHours < 24) return '${diff.inHours}h';
      return '${diff.inDays}d';
    } catch (_) { return ''; }
  }

  List<Map<String, String>> get _filtered => _activeDomain == 0 ? _allArticles : _allArticles.where((a) => a['cat'] == _domains[_activeDomain]).toList();

  Future<void> _generateDigest() async {
    setState(() { _digestLoading = true; _digestText = null; });
    try {
      final headlines = _filtered.take(20).map((a) => '• [${a['source']}] ${a['title']}').join('\n');
      final apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
      final promptText = 'System: You are a senior tech career strategist analyzing real-time tech news for a software developer.\n\nHere are today\'s live tech headlines:\n$headlines\n\nCreate a personalized intelligence briefing:\n🎯 **Top Priority** (1 item): The most career-impactful news and why\n📈 **Trending Now** (2-3 items): Technologies gaining momentum\n⚡ **Action Items** (2-3 items): Specific things to learn or explore this week\n\nReference actual headlines. Be specific. Max 120 words.';

      try {
        final geminiUrl = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$apiKey';
        final resp = await http.post(
          Uri.parse(geminiUrl),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'contents': [{'parts': [{'text': promptText}]}]}),
        ).timeout(const Duration(seconds: 15));
        if (resp.statusCode == 200) {
          final data = jsonDecode(resp.body);
          setState(() => _digestText = data['candidates'][0]['content']['parts'][0]['text']);
        } else {
          throw Exception('Gemini HTTP ${resp.statusCode}');
        }
      } catch (e) {
        debugPrint('Gemini tech feed failed, falling back to Groq: $e');
        final groqApiKey = dotenv.env['GROQ_API_KEY'] ?? '';
        final resp = await http.post(
          Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
          headers: {
            'Authorization': 'Bearer $groqApiKey',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'model': 'llama-3.3-70b-versatile',
            'messages': [{'role': 'user', 'content': promptText}],
            'temperature': 0.3,
          }),
        );
        if (resp.statusCode == 200) {
          final data = jsonDecode(resp.body);
          setState(() => _digestText = data['choices'][0]['message']['content']);
        } else {
          setState(() => _digestText = 'API error: ${resp.statusCode} (Groq fallback)');
        }
      }
    } catch (e) { setState(() => _digestText = 'Error: $e'); }
    finally { setState(() => _digestLoading = false); }
  }

  @override
  Widget build(BuildContext context) {
    final articles = _filtered;
    final color = _domainColors[_activeDomain];
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: SafeArea(child: RefreshIndicator(
        onRefresh: _fetchAllFeeds,
        child: CustomScrollView(slivers: [
          // Header
          SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(20, 20, 20, 0), child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                GestureDetector(onTap: () => Navigator.pop(context), child: const Icon(LucideIcons.arrowLeft, size: 22)),
                const SizedBox(width: 10),
                Text('Tech Feed', style: Theme.of(context).textTheme.headlineLarge),
              ]),
              const SizedBox(height: 2),
              Text('${_allArticles.length} live articles from ${_rssSources.length} sources', style: const TextStyle(color: AppColors.textSecondaryLight, fontSize: 12)),
            ])),
            GestureDetector(
              onTap: _digestLoading ? null : _generateDigest,
              child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(gradient: LinearGradient(colors: [color, color.withValues(alpha: 0.7)]), borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4))]),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  _digestLoading ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(LucideIcons.sparkles, color: Colors.white, size: 14),
                  const SizedBox(width: 5), const Text('AI Digest', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                ]),
              ),
            ),
          ]))),
          const SliverToBoxAdapter(child: SizedBox(height: 16)),

          // Category tabs
          SliverToBoxAdapter(child: SizedBox(height: 44, child: ListView.separated(
            scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: _domains.length, separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final sel = _activeDomain == i;
              final c = _domainColors[i];
              final count = i == 0 ? _allArticles.length : _allArticles.where((a) => a['cat'] == _domains[i]).length;
              return GestureDetector(onTap: () => setState(() => _activeDomain = i),
                child: AnimatedContainer(duration: const Duration(milliseconds: 250),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    gradient: sel ? LinearGradient(colors: [c, c.withValues(alpha: 0.7)]) : null,
                    color: sel ? null : AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(14),
                    border: sel ? null : Border.all(color: const Color(0xFFE8DDD2)),
                    boxShadow: sel ? [BoxShadow(color: c.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 3))] : null,
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(_domainIcons[i], size: 14, color: sel ? Colors.white : AppColors.textSecondaryLight),
                    const SizedBox(width: 6),
                    Text(_domains[i], style: TextStyle(color: sel ? Colors.white : AppColors.textSecondaryLight, fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(width: 4),
                    Container(padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1), decoration: BoxDecoration(color: sel ? Colors.white24 : const Color(0xFFEDE5D8), borderRadius: BorderRadius.circular(6)),
                      child: Text('$count', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: sel ? Colors.white : AppColors.textSecondaryLight))),
                  ]),
                ),
              );
            },
          ))),
          const SliverToBoxAdapter(child: SizedBox(height: 16)),

          // AI Digest result
          if (_digestText != null) SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Container(
            width: double.infinity, padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withValues(alpha: 0.2))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [Icon(LucideIcons.sparkles, size: 14, color: color), const SizedBox(width: 6), Text('AI Intelligence Briefing', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color)),
                const Spacer(), GestureDetector(onTap: () => setState(() => _digestText = null), child: Icon(LucideIcons.x, size: 14, color: color))]),
              const SizedBox(height: 8),
              Text(_digestText!, style: const TextStyle(fontSize: 13, height: 1.5, color: AppColors.textPrimaryLight)),
            ]),
          ))),
          if (_digestText != null) const SliverToBoxAdapter(child: SizedBox(height: 16)),

          // Loading state
          if (_loading) SliverToBoxAdapter(child: Center(child: Padding(padding: const EdgeInsets.all(60),
            child: Column(children: [
              const CircularProgressIndicator(color: AppColors.primary),
              const SizedBox(height: 16),
              const Text('Fetching live RSS feeds…', style: TextStyle(color: AppColors.textSecondaryLight, fontSize: 13)),
            ]),
          ))),

          // Empty state
          if (!_loading && articles.isEmpty) SliverToBoxAdapter(child: Center(child: Padding(padding: const EdgeInsets.all(60),
            child: Column(children: [
              const Icon(LucideIcons.wifiOff, size: 40, color: AppColors.textSecondaryLight),
              const SizedBox(height: 12),
              const Text('No articles loaded', style: TextStyle(color: AppColors.textSecondaryLight)),
              const SizedBox(height: 12),
              ElevatedButton.icon(onPressed: _fetchAllFeeds, icon: const Icon(LucideIcons.refreshCw, size: 14), label: const Text('Retry')),
            ]),
          ))),

          // Article list
          if (!_loading) SliverList(delegate: SliverChildBuilderDelegate(
            (ctx, i) {
              final a = articles[i];
              return Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 10), child: _articleTile(a, color));
            },
            childCount: articles.length,
          )),
          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ]),
      )),
    );
  }

  Widget _articleTile(Map<String, String> a, Color domainColor) {
    final src = a['source'] ?? '';
    final srcColor = src == 'Dev.to' ? const Color(0xFF10B981) : src == 'Hacker News' ? const Color(0xFFFF6600) : src == 'GitHub' ? const Color(0xFF24292F) : src == 'TechCrunch' ? const Color(0xFF0A9E01) : const Color(0xFF000000);
    return GestureDetector(
      onTap: () { final url = a['link'] ?? ''; if (url.isNotEmpty) launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication); },
      child: Container(padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppColors.surfaceLight, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE8DDD2)),
          boxShadow: [BoxShadow(color: const Color(0xFFC4B5A0).withValues(alpha: 0.08), blurRadius: 8, offset: const Offset(0, 3))]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: srcColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
              child: Text(src, style: TextStyle(color: srcColor, fontSize: 10, fontWeight: FontWeight.bold))),
            const Spacer(),
            if ((a['time'] ?? '').isNotEmpty) Text('${a['time']} ago', style: const TextStyle(color: AppColors.textSecondaryLight, fontSize: 10)),
            const SizedBox(width: 6),
            const Icon(LucideIcons.externalLink, size: 12, color: AppColors.textSecondaryLight),
          ]),
          const SizedBox(height: 8),
          Text(a['title'] ?? '', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimaryLight, height: 1.3), maxLines: 2, overflow: TextOverflow.ellipsis),
          if ((a['desc'] ?? '').isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(a['desc']!, style: const TextStyle(color: AppColors.textSecondaryLight, fontSize: 12, height: 1.4), maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
        ]),
      ),
    );
  }
}
