/// scam_analysis_model.dart
///
/// Mirrors the Python ScamAnalysisResult Pydantic model.
/// Hand-written fromJson/toJson — no code generation required.
library;

import 'package:flutter/material.dart';

/// Trust score levels returned by the scam detection pipeline.
enum ScamTrustScore { verified, caution, flagged }

class ScamAnalysisModel {
  const ScamAnalysisModel({
    required this.jobId,
    required this.trustScore,
    required this.confidence,
    required this.flagReasons,
    required this.ruleTriggers,
    this.mlScore,
    required this.communityFlagCount,
    required this.verifiedCompany,
    required this.analysedAt,
    required this.fromCache,
  });

  final String jobId;
  final ScamTrustScore trustScore;
  final double confidence;
  final List<String> flagReasons;
  final List<String> ruleTriggers;
  final double? mlScore;
  final int communityFlagCount;
  final bool verifiedCompany;
  final DateTime analysedAt;
  final bool fromCache;

  // ── Helper getters ─────────────────────────────────────────────────────────

  /// Returns the appropriate colour for the trust badge in the UI.
  Color get trustColor {
    switch (trustScore) {
      case ScamTrustScore.verified:
        return Colors.green;
      case ScamTrustScore.caution:
        return Colors.orange;
      case ScamTrustScore.flagged:
        return Colors.red;
    }
  }

  /// Human-readable label for the trust score.
  String get trustLabel {
    switch (trustScore) {
      case ScamTrustScore.verified:
        return 'Verified';
      case ScamTrustScore.caution:
        return 'Caution';
      case ScamTrustScore.flagged:
        return 'Flagged';
    }
  }

  /// Returns an appropriate icon for the trust score.
  IconData get trustIcon {
    switch (trustScore) {
      case ScamTrustScore.verified:
        return Icons.verified_user;
      case ScamTrustScore.caution:
        return Icons.warning_amber_rounded;
      case ScamTrustScore.flagged:
        return Icons.dangerous_rounded;
    }
  }

  /// Confidence as a percentage string (e.g., "87%").
  String get confidencePercent => '${(confidence * 100).round()}%';

  // ── Deserialisation ────────────────────────────────────────────────────────

  factory ScamAnalysisModel.fromJson(Map<String, dynamic> json) {
    return ScamAnalysisModel(
      jobId: json['job_id'] as String,
      trustScore: _parseTrustScore(json['trust_score'] as String),
      confidence: (json['confidence'] as num).toDouble(),
      flagReasons:
          (json['flag_reasons'] as List<dynamic>? ?? []).cast<String>(),
      ruleTriggers:
          (json['rule_triggers'] as List<dynamic>? ?? []).cast<String>(),
      mlScore: json['ml_score'] != null
          ? (json['ml_score'] as num).toDouble()
          : null,
      communityFlagCount: json['community_flag_count'] as int? ?? 0,
      verifiedCompany: json['verified_company'] as bool? ?? false,
      analysedAt: DateTime.parse(json['analysed_at'] as String),
      fromCache: json['from_cache'] as bool? ?? false,
    );
  }

  // ── Serialisation ──────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
        'job_id': jobId,
        'trust_score': trustScore.name,
        'confidence': confidence,
        'flag_reasons': flagReasons,
        'rule_triggers': ruleTriggers,
        'ml_score': mlScore,
        'community_flag_count': communityFlagCount,
        'verified_company': verifiedCompany,
        'analysed_at': analysedAt.toIso8601String(),
        'from_cache': fromCache,
      };

  // ── Helpers ────────────────────────────────────────────────────────────────

  static ScamTrustScore _parseTrustScore(String raw) {
    switch (raw) {
      case 'caution':
        return ScamTrustScore.caution;
      case 'flagged':
        return ScamTrustScore.flagged;
      default:
        return ScamTrustScore.verified;
    }
  }

  @override
  String toString() =>
      'ScamAnalysisModel(jobId: $jobId, trustScore: ${trustScore.name}, confidence: $confidencePercent)';
}
