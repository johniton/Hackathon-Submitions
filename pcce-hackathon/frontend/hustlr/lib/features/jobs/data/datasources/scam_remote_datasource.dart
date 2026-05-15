/// scam_remote_datasource.dart
///
/// Calls the Python FastAPI scam detection endpoints via the `http` package.
///
/// Endpoints consumed:
///   POST /scam/analyse  → ScamAnalysisModel
///   POST /scam/report   → bool
///
/// Base URL is shared with the Job Scraper datasource (JOB_SERVICE_URL).
library;

import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../domain/models/scam_analysis_model.dart';

// ─── Typed exception ──────────────────────────────────────────────────────────

class ScamServiceException implements Exception {
  const ScamServiceException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;

  @override
  String toString() =>
      'ScamServiceException(statusCode: $statusCode): $message';
}

// ─── Datasource ───────────────────────────────────────────────────────────────

class ScamRemoteDatasource {
  ScamRemoteDatasource({http.Client? client})
      : _client = client ?? http.Client();

  static const String _baseUrl = String.fromEnvironment(
    'JOB_SERVICE_URL',
    defaultValue: 'http://10.24.226.196:8001',
  );

  static const Duration _analyseTimeout = Duration(seconds: 15);
  static const Duration _reportTimeout = Duration(seconds: 5);

  final http.Client _client;

  // ── POST /scam/analyse ──────────────────────────────────────────────────

  /// Runs the full scam detection pipeline for a job listing.
  /// Returns a [ScamAnalysisModel] on success.
  /// Throws [ScamServiceException] on non-200 responses or network errors.
  Future<ScamAnalysisModel> analyseJob(String jobId) async {
    final uri = Uri.parse('$_baseUrl/scam/analyse');
    try {
      final response = await _client
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'listing': {'id': jobId},
            }),
          )
          .timeout(_analyseTimeout);

      _assertOk(response);

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return ScamAnalysisModel.fromJson(body);
    } on ScamServiceException {
      rethrow;
    } catch (e) {
      throw ScamServiceException('analyseJob failed: $e');
    }
  }

  // ── POST /scam/report ───────────────────────────────────────────────────

  /// Submits a community scam report for a job listing.
  /// Returns true on success, false otherwise.
  /// Throws [ScamServiceException] on non-200 responses or network errors.
  Future<bool> reportScam(
    String jobId,
    String userId,
    String reason, [
    String? details,
  ]) async {
    final uri = Uri.parse('$_baseUrl/scam/report');
    try {
      final payload = <String, dynamic>{
        'job_id': jobId,
        'user_id': userId,
        'reason': reason,
      };
      if (details != null && details.isNotEmpty) {
        payload['details'] = details;
      }

      final response = await _client
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(_reportTimeout);

      _assertOk(response);

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return body['success'] as bool? ?? false;
    } on ScamServiceException {
      rethrow;
    } catch (e) {
      throw ScamServiceException('reportScam failed: $e');
    }
  }

  // ── Helpers ─────────────────────────────────────────────────────────────

  void _assertOk(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      String message;
      try {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        message = body['detail']?.toString() ?? response.body;
      } catch (_) {
        message = response.body;
      }
      throw ScamServiceException(message, statusCode: response.statusCode);
    }
  }
}
