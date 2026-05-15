/// Hustlr Smart Resume Builder — API Service
/// All HTTP calls to the backend resume endpoints.

import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:hustlr/config.dart';
import 'resume_models.dart';

class ResumeService {
  static String get _base => AppConfig.baseUrl;

  /// Fetch GitHub repos + user profile
  static Future<Map<String, dynamic>> fetchGithubData(String githubUrl, {String? token}) async {
    final request = http.MultipartRequest('POST', Uri.parse('$_base/resume/github'));
    request.fields['github_url'] = githubUrl;
    if (token != null && token.isNotEmpty) request.fields['github_token'] = token;

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final repos = (data['repos'] as List).map((r) => GithubRepo.fromJson(r)).toList();
      final profile = data['profile'] as Map<String, dynamic>? ?? {};
      return {'repos': repos, 'profile': profile};
    }
    throw Exception('GitHub fetch failed: ${response.body}');
  }

  /// Scrape LinkedIn profile (auto-scrape via URL)
  static Future<Map<String, dynamic>> scrapeLinkedIn(String url) async {
    final request = http.MultipartRequest('POST', Uri.parse('$_base/resume/linkedin'));
    request.fields['url'] = url;

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return {
        'profile': data['profile'] != null ? LinkedInProfile.fromJson(data['profile']) : null,
        'status': data['status'] ?? 'failed',
      };
    }
    return {'profile': null, 'status': 'failed'};
  }

  /// Parse pasted LinkedIn profile text with AI
  static Future<LinkedInProfile?> parseProfileText(String text) async {
    final request = http.MultipartRequest('POST', Uri.parse('$_base/resume/parse-profile'));
    request.fields['text'] = text;

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if ((data['status'] == 'parsed') && data['profile'] != null) {
        return LinkedInProfile.fromJson(data['profile']);
      }
    }
    return null;
  }

  /// OCR a certificate file
  static Future<CertificateInfo> ocrCertificate(String filePath, String fileName) async {
    final request = http.MultipartRequest('POST', Uri.parse('$_base/resume/ocr'));
    request.files.add(await http.MultipartFile.fromPath('file', filePath, filename: fileName));

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode == 200) {
      return CertificateInfo.fromJson(jsonDecode(response.body));
    }
    throw Exception('OCR failed: ${response.body}');
  }

  /// Generate resume (full AI pipeline)
  static Future<GenerateResult> generateResume({
    required Map<String, dynamic> candidateProfile,
    required List<GithubRepo> selectedRepos,
    String jdText = '',
    String extraInfo = '',
    String templateName = 'ats_safe',
    String? githubToken,
  }) async {
    final request = http.MultipartRequest('POST', Uri.parse('$_base/resume/generate'));
    request.fields['candidate_profile'] = jsonEncode(candidateProfile);
    request.fields['selected_repos'] = jsonEncode(selectedRepos.map((r) => r.toJson()).toList());
    request.fields['jd_text'] = jdText;
    request.fields['extra_info'] = extraInfo;
    request.fields['template_name'] = templateName;
    if (githubToken != null) request.fields['github_token'] = githubToken;

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode == 200) {
      return GenerateResult.fromJson(jsonDecode(response.body));
    }
    throw Exception('Generate failed: ${response.body}');
  }

  /// Export resume as PDF (returns bytes)
  static Future<Uint8List> exportPdf(Map<String, dynamic> resumeJson, String templateName) async {
    final request = http.MultipartRequest('POST', Uri.parse('$_base/resume/export/pdf'));
    request.fields['resume_json'] = jsonEncode(resumeJson);
    request.fields['template_name'] = templateName;

    final streamed = await request.send();
    if (streamed.statusCode == 200) {
      return await streamed.stream.toBytes();
    }
    final response = await http.Response.fromStream(streamed);
    throw Exception('PDF export failed: ${response.body}');
  }

  /// Export resume as DOCX (returns bytes)
  static Future<Uint8List> exportDocx(Map<String, dynamic> resumeJson) async {
    final request = http.MultipartRequest('POST', Uri.parse('$_base/resume/export/docx'));
    request.fields['resume_json'] = jsonEncode(resumeJson);

    final streamed = await request.send();
    if (streamed.statusCode == 200) {
      return await streamed.stream.toBytes();
    }
    final response = await http.Response.fromStream(streamed);
    throw Exception('DOCX export failed: ${response.body}');
  }

  /// Match resume against JD
  static Future<Map<String, dynamic>> matchJd(Map<String, dynamic> resumeJson, String jdText) async {
    final request = http.MultipartRequest('POST', Uri.parse('$_base/resume/match-jd'));
    request.fields['resume_json'] = jsonEncode(resumeJson);
    request.fields['jd_text'] = jdText;

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('JD match failed: ${response.body}');
  }
}
