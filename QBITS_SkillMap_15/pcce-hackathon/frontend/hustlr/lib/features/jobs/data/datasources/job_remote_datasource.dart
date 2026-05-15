/// job_remote_datasource.dart
///
/// Calls the Python FastAPI Job Scraper microservice via the `http` package.
///
/// Base URL is read from the dart-define compile-time variable JOB_SERVICE_URL.
/// Override at build/run time:
///   flutter run --dart-define=JOB_SERVICE_URL=http://10.0.2.2:8001
///
/// Default: http://localhost:8001 (works for Flutter web & desktop dev).

import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../domain/models/job_listing_model.dart';

// ─── Typed exceptions (datasource layer — not exposed to UI) ──────────────────

class JobServiceException implements Exception {
  const JobServiceException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;

  @override
  String toString() =>
      'JobServiceException(statusCode: $statusCode): $message';
}

class JobNotFoundException implements Exception {
  const JobNotFoundException(this.jobId);
  final String jobId;

  @override
  String toString() => 'JobNotFoundException: Job "$jobId" not found.';
}

// ─── Datasource ───────────────────────────────────────────────────────────────

class JobRemoteDatasource {
  JobRemoteDatasource({http.Client? client})
      : _client = client ?? http.Client();

  static const String _baseUrl = String.fromEnvironment(
    'JOB_SERVICE_URL',
    defaultValue: 'http://10.24.226.196:8001',
  );

  static const Duration _timeout = Duration(seconds: 30);

  final http.Client _client;

  // ── POST /jobs/search ────────────────────────────────────────────────────

  /// Returns a [ScrapedJobResponse] on success.
  /// Throws [JobServiceException] on non-200 responses or network errors.
  Future<ScrapedJobResponse> searchJobs(SearchJobsParams params) async {
    final uri = Uri.parse('$_baseUrl/jobs/search');
    try {
      final response = await _client
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(params.toJson()),
          )
          .timeout(_timeout);

      _assertOk(response);

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return ScrapedJobResponse.fromJson(body);
    } on JobServiceException {
      rethrow;
    } catch (e) {
      throw JobServiceException('searchJobs failed: $e');
    }
  }

  // ── GET /jobs/{id} ───────────────────────────────────────────────────────

  /// Returns a [JobListingModel] on success.
  /// Throws [JobNotFoundException] on 404 or [JobServiceException] on other errors.
  Future<JobListingModel> getJobById(String id) async {
    final uri = Uri.parse('$_baseUrl/jobs/$id');
    try {
      final response = await _client.get(uri).timeout(_timeout);

      if (response.statusCode == 404) {
        throw JobNotFoundException(id);
      }
      _assertOk(response);

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return JobListingModel.fromJson(body);
    } on JobNotFoundException {
      rethrow;
    } on JobServiceException {
      rethrow;
    } catch (e) {
      throw JobServiceException('getJobById failed: $e');
    }
  }

  // ── POST /jobs/scam-check ────────────────────────────────────────────────

  /// Returns a [ScamCheckResponse] on success.
  /// Throws [JobServiceException] or [JobNotFoundException].
  Future<ScamCheckResponse> checkScam(String jobId) async {
    final uri = Uri.parse('$_baseUrl/jobs/scam-check');
    try {
      final response = await _client
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'job_id': jobId}),
          )
          .timeout(_timeout);

      if (response.statusCode == 404) {
        throw JobNotFoundException(jobId);
      }
      _assertOk(response);

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return ScamCheckResponse.fromJson(body);
    } on JobNotFoundException {
      rethrow;
    } on JobServiceException {
      rethrow;
    } catch (e) {
      throw JobServiceException('checkScam failed: $e');
    }
  }

  // ── GET /health ──────────────────────────────────────────────────────────

  /// Returns true if the microservice is reachable and healthy.
  Future<bool> isHealthy() async {
    try {
      final response = await _client
          .get(Uri.parse('$_baseUrl/health'))
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  void _assertOk(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      String message;
      try {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        message = body['detail']?.toString() ?? response.body;
      } catch (_) {
        message = response.body;
      }
      throw JobServiceException(message, statusCode: response.statusCode);
    }
  }
}
