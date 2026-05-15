/// Hustlr AI Interview — API Service
/// Handles all HTTP communication with the interview backend.

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:hustlr/config.dart';
import 'interview_models.dart';

class InterviewService {
  // Reads from lib/config.dart → change backendIp there
  static String get _baseUrl => AppConfig.baseUrl;

  /// Start a new interview session with setup context
  static Future<InterviewStartResult> startInterview(InterviewSetup setup) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/interview/start'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(setup.toJson()),
    );

    if (response.statusCode == 200) {
      return InterviewStartResult.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to start interview: ${response.body}');
    }
  }

  /// Submit a video answer for a question
  static Future<SubmitResult> submitAnswer(
    String sessionId,
    String questionId,
    String videoPath,
  ) async {
    final uri = Uri.parse('$_baseUrl/interview/submit');
    final request = http.MultipartRequest('POST', uri);

    request.fields['session_id'] = sessionId;
    request.fields['question_id'] = questionId;

    final ext = videoPath.split('.').last.toLowerCase();
    final mimeType = ext == 'mp4' ? 'video/mp4' : 'video/$ext';

    request.files.add(await http.MultipartFile.fromPath(
      'video',
      videoPath,
      filename: 'answer.$ext',
      contentType: MediaType.parse(mimeType),
    ));

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      return SubmitResult.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to submit answer: ${response.body}');
    }
  }

  /// Mark interview as complete — triggers async scoring pipeline
  static Future<void> completeInterview(String sessionId) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/interview/complete'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'session_id': sessionId}),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to complete interview: ${response.body}');
    }
  }

  /// Poll for interview results
  static Future<InterviewResult> getResult(String sessionId) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/interview/$sessionId/result'),
    );

    if (response.statusCode == 200) {
      return InterviewResult.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to get result: ${response.body}');
    }
  }

  /// Verify face against baseline
  static Future<bool> verifyFace(String baselineImagePath, String currentImagePath) async {
    final uri = Uri.parse('$_baseUrl/interview/verify_face');
    final request = http.MultipartRequest('POST', uri);

    request.files.add(await http.MultipartFile.fromPath('baseline_image', baselineImagePath));
    request.files.add(await http.MultipartFile.fromPath('current_image', currentImagePath));

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      return json['verified'] == true;
    } else {
      throw Exception('Face verification failed: ${response.body}');
    }
  }

  /// Mark interview as cheating
  static Future<void> markCheating(String sessionId) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/interview/$sessionId/mark_cheating'),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to mark cheating: ${response.body}');
    }
  }
}
