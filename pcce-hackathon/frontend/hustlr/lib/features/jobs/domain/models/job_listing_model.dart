/// job_listing_model.dart
///
/// Mirror of the Python Pydantic [JobListing] model.
/// Hand-written fromJson/toJson — no code generation required.

// ignore_for_file: invalid_annotation_target

enum JobSource { linkedin, naukri, instahyre, internshala, shine }

enum TrustScore { verified, caution, flagged }

class JobListingModel {
  const JobListingModel({
    required this.id,
    required this.title,
    required this.company,
    required this.location,
    this.salaryRange,
    this.experienceRequired,
    required this.skillsRequired,
    required this.description,
    required this.source,
    required this.sourceUrl,
    this.postedAt,
    required this.scrapedAt,
    required this.freshnessDays,
    required this.trustScore,
    required this.flagReasons,
    required this.scamPercentage,
    required this.matchScore,
    required this.isDuplicate,
  });

  final String id;
  final String title;
  final String company;
  final String location;
  final String? salaryRange;
  final String? experienceRequired;
  final List<String> skillsRequired;
  final String description;
  final JobSource source;
  final String sourceUrl;
  final DateTime? postedAt;
  final DateTime scrapedAt;
  final int freshnessDays;
  final TrustScore trustScore;
  final List<String> flagReasons;
  final int scamPercentage;

  /// Jaccard similarity score against the user's skill profile (0.0–1.0).
  final double matchScore;

  final bool isDuplicate;

  // ── Deserialisation ────────────────────────────────────────────────────────

  factory JobListingModel.fromJson(Map<String, dynamic> json) {
    return JobListingModel(
      id: json['id'] as String,
      title: json['title'] as String,
      company: json['company'] as String,
      location: json['location'] as String,
      salaryRange: json['salary_range'] as String?,
      experienceRequired: json['experience_required'] as String?,
      skillsRequired:
          (json['skills_required'] as List<dynamic>? ?? []).cast<String>(),
      description: json['description'] as String,
      source: _parseSource(json['source'] as String),
      sourceUrl: json['source_url'] as String,
      postedAt: json['posted_at'] != null
          ? DateTime.tryParse(json['posted_at'] as String)
          : null,
      scrapedAt: DateTime.parse(json['scraped_at'] as String),
      freshnessDays: json['freshness_days'] as int? ?? 0,
      trustScore: _parseTrustScore(json['trust_score'] as String),
      flagReasons:
          (json['flag_reasons'] as List<dynamic>? ?? []).cast<String>(),
      scamPercentage: json['scam_percentage'] as int? ?? 0,
      matchScore: (json['match_score'] as num? ?? 0.0).toDouble(),
      isDuplicate: json['is_duplicate'] as bool? ?? false,
    );
  }

  // ── Serialisation ──────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'company': company,
        'location': location,
        'salary_range': salaryRange,
        'experience_required': experienceRequired,
        'skills_required': skillsRequired,
        'description': description,
        'source': source.name,
        'source_url': sourceUrl,
        'posted_at': postedAt?.toIso8601String(),
        'scraped_at': scrapedAt.toIso8601String(),
        'freshness_days': freshnessDays,
        'trust_score': trustScore.name,
        'flag_reasons': flagReasons,
        'scam_percentage': scamPercentage,
        'match_score': matchScore,
        'is_duplicate': isDuplicate,
      };

  // ── Helpers ────────────────────────────────────────────────────────────────

  static JobSource _parseSource(String raw) {
    switch (raw) {
      case 'naukri': return JobSource.naukri;
      case 'instahyre': return JobSource.instahyre;
      case 'internshala': return JobSource.internshala;
      case 'shine': return JobSource.shine;
      default: return JobSource.linkedin;
    }
  }

  static TrustScore _parseTrustScore(String raw) {
    switch (raw) {
      case 'caution':
        return TrustScore.caution;
      case 'flagged':
        return TrustScore.flagged;
      default:
        return TrustScore.verified;
    }
  }

  @override
  String toString() => 'JobListingModel(id: $id, title: $title, company: $company)';
}

// ─── Search params ─────────────────────────────────────────────────────────────

class SearchJobsParams {
  const SearchJobsParams({
    required this.keywords,
    required this.location,
    this.experienceYears = 0,
    this.userSkills = const [],
    this.freshnessDays = 7,
    this.sources = const ['linkedin', 'naukri', 'instahyre', 'internshala', 'shine'],
  });

  final String keywords;
  final String location;
  final int experienceYears;
  final List<String> userSkills;
  final int freshnessDays;
  final List<String> sources;

  Map<String, dynamic> toJson() => {
        'keywords': keywords,
        'location': location,
        'experience_years': experienceYears,
        'user_skills': userSkills,
        'freshness_days': freshnessDays,
        'sources': sources,
      };
}

// ─── API response wrapper ──────────────────────────────────────────────────────

class ScrapedJobResponse {
  const ScrapedJobResponse({
    required this.jobs,
    required this.total,
    required this.fromCache,
  });

  final List<JobListingModel> jobs;
  final int total;
  final bool fromCache;

  factory ScrapedJobResponse.fromJson(Map<String, dynamic> json) {
    return ScrapedJobResponse(
      jobs: (json['jobs'] as List<dynamic>)
          .map((j) => JobListingModel.fromJson(j as Map<String, dynamic>))
          .toList(),
      total: json['total'] as int,
      fromCache: json['from_cache'] as bool? ?? false,
    );
  }
}

// ─── Scam check response ───────────────────────────────────────────────────────

class ScamCheckResponse {
  const ScamCheckResponse({
    required this.trustScore,
    required this.flagReasons,
  });

  final TrustScore trustScore;
  final List<String> flagReasons;

  factory ScamCheckResponse.fromJson(Map<String, dynamic> json) {
    return ScamCheckResponse(
      trustScore: JobListingModel._parseTrustScore(json['trust_score'] as String),
      flagReasons: (json['flag_reasons'] as List<dynamic>).cast<String>(),
    );
  }
}
