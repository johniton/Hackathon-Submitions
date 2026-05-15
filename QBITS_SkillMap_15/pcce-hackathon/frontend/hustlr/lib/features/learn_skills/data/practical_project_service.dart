import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hustlr/features/flashcards/data/ai_flashcard_service.dart';

/// Service for managing practical projects: persistence, GitHub review, and rating.
class PracticalProjectService {
  static const String geminiModel = 'gemini-2.5-flash';
  static String get geminiApiKey => dotenv.env['GEMINI_API_KEY'] ?? '';

  // Persist/load practical project packs so they stay stable per roadmap+role
  static String _practicalKey(String roadmapName, String skillOrRole) =>
      'practical:${roadmapName.trim().toLowerCase()}:${skillOrRole.trim().toLowerCase()}';

  static Future<void> persistPracticalProjectPack(
    String roadmapName,
    String skillOrRole,
    PracticalProjectPack pack,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_practicalKey(roadmapName, skillOrRole), jsonEncode(pack.toJson()));
  }

  static Future<PracticalProjectPack?> loadPracticalProjectPack(
    String roadmapName,
    String skillOrRole,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_practicalKey(roadmapName, skillOrRole));
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final parsed = jsonDecode(raw) as Map<String, dynamic>;
      final projects = <PracticalProject>[];
      final list = parsed['projects'] as List? ?? [];
      for (final item in list) {
        final m = item as Map<String, dynamic>;
        projects.add(PracticalProject(
          title: (m['title'] as String?) ?? '',
          rolePlayContext: (m['rolePlayContext'] as String?) ?? '',
          whyItMatters: (m['whyItMatters'] as String?) ?? '',
          deliverables: (m['deliverables'] as List? ?? []).map((e) => e.toString()).toList(),
          starterSteps: (m['starterSteps'] as List? ?? []).map((e) => e.toString()).toList(),
          skills: (m['skills'] as List? ?? []).map((e) => e.toString()).toList(),
        ));
      }
      return PracticalProjectPack(
        title: parsed['title'] as String? ?? 'Practical Projects',
        skillOrRole: parsed['skillOrRole'] as String? ?? skillOrRole,
        projects: projects,
        createdAt: DateTime.tryParse(parsed['createdAt'] as String? ?? '') ?? DateTime.now(),
      );
    } catch (e) {
      return null;
    }
  }

  /// Perform a Gemini-based review of a public GitHub repo.
  /// Returns a numeric rating out of 10 based on code completeness and quality.
  static Future<int> reviewGitHubRepo(
    String repoUrl,
    PracticalProject project,
  ) async {
    // Basic parse of https://github.com/owner/repo or owner/repo
    final uri = Uri.tryParse(repoUrl.trim());
    String owner = '';
    String repo = '';
    if (uri != null && (uri.host.contains('github.com') || uri.host.isEmpty)) {
      final parts = uri.path.split('/').where((p) => p.isNotEmpty).toList();
      if (parts.length >= 2) {
        owner = parts[0];
        repo = parts[1].replaceAll('.git', '');
      }
    }
    if (owner.isEmpty || repo.isEmpty) {
      // Try fallback parsing owner/repo
      final fallback = repoUrl.trim().replaceAll(r'git@github.com:', '').replaceAll('.git', '');
      final parts = fallback.split('/');
      if (parts.length >= 2) {
        owner = parts[0];
        repo = parts[1];
      }
    }

    if (owner.isEmpty || repo.isEmpty) {
      throw StateError('Invalid GitHub repository URL.');
    }

    // List root contents
    final apiRoot = Uri.https('api.github.com', '/repos/$owner/$repo/contents/');
    final listResp = await http.get(apiRoot, headers: {'Accept': 'application/vnd.github.v3+json'});
    if (listResp.statusCode != 200) {
      throw StateError('Unable to access GitHub repo: ${listResp.statusCode}');
    }

    final items = jsonDecode(listResp.body) as List<dynamic>;
    String readmeContent = '';
    final candidates = <String>[];
    for (final it in items) {
      final m = it as Map<String, dynamic>;
      final name = (m['name'] as String?)?.toLowerCase() ?? '';
      final download = m['download_url'] as String?;
      if (name.startsWith('readme') && download != null) {
        readmeContent = await _fetchRaw(download);
      }
      if (name == 'pubspec.yaml' || name == 'package.json' || name == 'README.md') {
        if (download != null) candidates.add(download);
      }
      if (m['type'] == 'dir' && (m['name'] == 'lib' || m['name'] == 'src')) {
        // try list inside dir
        final dirResp = await http.get(Uri.parse(m['url']), headers: {'Accept': 'application/vnd.github.v3+json'});
        if (dirResp.statusCode == 200) {
          final dirItems = jsonDecode(dirResp.body) as List<dynamic>;
          for (final di in dirItems.take(5)) {
            final dm = di as Map<String, dynamic>;
            if ((dm['download_url'] as String?) != null) candidates.add(dm['download_url'] as String);
          }
        }
      }
    }

    // fetch up to 3 candidate files
    final snippets = <String>[];
    if (readmeContent.isNotEmpty) snippets.add('README:\n${readmeContent.length > 3000 ? readmeContent.substring(0, 3000) : readmeContent}');
    for (final d in candidates.take(3)) {
      try {
        final content = await _fetchRaw(d);
        snippets.add('${d.split('/').last}:\n${content.length > 2000 ? content.substring(0, 2000) : content}');
      } catch (_) {}
    }

    final prompt = '''You are an expert code reviewer. The user submitted a GitHub repository to complete this practical task. The project requirements and deliverables are below.

Project deliverables (must have all):
${project.deliverables.join('\n')}

Starter steps (should implement):
${project.starterSteps.join('\n')}

Please read the repository excerpts below and rate the submission on a scale of 1-10 based on:
- Does it meet ALL deliverables? (critical)
- Code quality and organization
- Completeness and functionality
- README/documentation clarity

Return ONLY a single integer from 1-10 on a line by itself. Nothing else.

Repository excerpts:
${snippets.join('\n\n')}
''';

    if (geminiApiKey.isEmpty) throw StateError('Gemini API key is not set.');

    final geminiUri = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/$geminiModel:generateContent?key=$geminiApiKey');
    final resp = await http.post(
      geminiUri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'contents': [
          {
            'parts': [
              {'text': prompt},
            ],
          }
        ],
        'generationConfig': {'temperature': 0.1, 'maxOutputTokens': 10}
      }),
    );

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw StateError('Gemini review failed: ${resp.statusCode}');
    }

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final candidatesResp = data['candidates'] as List?;
    if (candidatesResp == null || candidatesResp.isEmpty) throw StateError('Gemini returned no review.');
    final content = (candidatesResp.first['content'] as Map<String, dynamic>?)?['parts'] as List?;
    final text = content?.first['text'] as String? ?? '';
    final cleaned = text.trim();

    // Extract the numeric rating from the response
    final rating = int.tryParse(cleaned) ?? 5; // default to 5 if parse fails
    return rating.clamp(1, 10);
  }

  static Future<String> _fetchRaw(String url) async {
    final r = await http.get(Uri.parse(url));
    if (r.statusCode == 200) return r.body;
    return '';
  }
}
