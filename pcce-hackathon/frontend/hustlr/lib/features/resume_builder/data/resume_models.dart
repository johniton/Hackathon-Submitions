/// Hustlr Smart Resume Builder — Data Models

class GithubRepo {
  final int id;
  final String name;
  final String fullName;
  final String description;
  final String language;
  final int stars;
  final String lastCommit;
  final List<String> topics;
  final String url;
  final bool isPrivate;
  bool selected;

  GithubRepo({
    required this.id,
    required this.name,
    required this.fullName,
    this.description = '',
    this.language = '',
    this.stars = 0,
    this.lastCommit = '',
    this.topics = const [],
    this.url = '',
    this.isPrivate = false,
    this.selected = false,
  });

  factory GithubRepo.fromJson(Map<String, dynamic> json) {
    return GithubRepo(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      fullName: json['full_name'] ?? '',
      description: json['description'] ?? '',
      language: json['language'] ?? '',
      stars: json['stars'] ?? 0,
      lastCommit: json['last_commit'] ?? '',
      topics: List<String>.from(json['topics'] ?? []),
      url: json['url'] ?? '',
      isPrivate: json['private'] ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id, 'name': name, 'full_name': fullName,
    'description': description, 'language': language,
    'stars': stars, 'url': url,
  };
}

class LinkedInProfile {
  final String name;
  final String headline;
  final String location;
  final String summary;
  final List<Map<String, dynamic>> experience;
  final List<Map<String, dynamic>> education;
  final List<String> skills;
  final List<Map<String, dynamic>> projects;
  final List<String> achievements;
  final List<Map<String, dynamic>> certifications;

  LinkedInProfile({
    this.name = '', this.headline = '', this.location = '',
    this.summary = '', this.experience = const [],
    this.education = const [], this.skills = const [],
    this.projects = const [], this.achievements = const [],
    this.certifications = const [],
  });

  factory LinkedInProfile.fromJson(Map<String, dynamic> json) {
    return LinkedInProfile(
      name: json['name'] ?? '',
      headline: json['headline'] ?? '',
      location: json['location'] ?? '',
      summary: json['summary'] ?? '',
      experience: List<Map<String, dynamic>>.from(json['experience'] ?? []),
      education: List<Map<String, dynamic>>.from(json['education'] ?? []),
      skills: List<String>.from(json['skills'] ?? []),
      projects: List<Map<String, dynamic>>.from(json['projects'] ?? []),
      achievements: List<String>.from(json['achievements'] ?? []),
      certifications: List<Map<String, dynamic>>.from(json['certifications'] ?? []),
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name, 'headline': headline, 'location': location,
    'summary': summary, 'experience': experience,
    'education': education, 'skills': skills,
    'projects': projects, 'achievements': achievements,
    'certifications': certifications,
  };
}

class CertificateInfo {
  final String certName;
  final String issuer;
  final String issueDate;
  final List<String> skills;
  final String rawText;

  CertificateInfo({
    this.certName = '', this.issuer = '', this.issueDate = '',
    this.skills = const [], this.rawText = '',
  });

  factory CertificateInfo.fromJson(Map<String, dynamic> json) {
    return CertificateInfo(
      certName: json['cert_name'] ?? '',
      issuer: json['issuer'] ?? '',
      issueDate: json['issue_date'] ?? '',
      skills: List<String>.from(json['skills'] ?? []),
      rawText: json['raw_text'] ?? '',
    );
  }
}

class ATSScore {
  final int score;
  final Map<String, dynamic> breakdown;
  final List<String> matchedKeywords;
  final List<String> missingKeywords;
  final List<String> suggestions;

  ATSScore({
    this.score = 0, this.breakdown = const {},
    this.matchedKeywords = const [], this.missingKeywords = const [],
    this.suggestions = const [],
  });

  factory ATSScore.fromJson(Map<String, dynamic> json) {
    return ATSScore(
      score: json['score'] ?? 0,
      breakdown: Map<String, dynamic>.from(json['breakdown'] ?? {}),
      matchedKeywords: List<String>.from(json['matched_keywords'] ?? []),
      missingKeywords: List<String>.from(json['missing_keywords'] ?? []),
      suggestions: List<String>.from(json['suggestions'] ?? []),
    );
  }
}

class GenerateResult {
  final Map<String, dynamic> resumeJson;
  final Map<String, dynamic> analysis;
  final ATSScore atsScore;
  final String template;

  GenerateResult({
    required this.resumeJson, required this.analysis,
    required this.atsScore, required this.template,
  });

  factory GenerateResult.fromJson(Map<String, dynamic> json) {
    return GenerateResult(
      resumeJson: Map<String, dynamic>.from(json['resume_json'] ?? {}),
      analysis: Map<String, dynamic>.from(json['analysis'] ?? {}),
      atsScore: ATSScore.fromJson(json['ats_score'] ?? {}),
      template: json['template'] ?? 'ats_safe',
    );
  }
}

/// Data holder passed through the resume flow
class ResumeFlowData {
  // Step 1: URLs
  String githubUrl = '';
  String githubToken = '';
  String linkedinUrl = '';
  LinkedInProfile? linkedinProfile;
  Map<String, dynamic>? manualProfile;
  Map<String, dynamic>? githubProfile; // from GitHub API

  // Step 2: Selected repos
  List<GithubRepo> selectedRepos = [];

  // Step 3: JD + Certs + Extras
  String jdText = '';
  List<CertificateInfo> certificates = [];
  String extraInfo = '';

  // Step 4: Template
  String templateName = 'ats_safe';

  // Result
  GenerateResult? result;

  Map<String, dynamic> buildCandidateProfile() {
    final profile = <String, dynamic>{};

    // Start with GitHub profile data as a base
    if (githubProfile != null) {
      if (githubProfile!['name'] != null) profile['name'] = githubProfile!['name'];
      if (githubProfile!['email'] != null) profile['email'] = githubProfile!['email'];
      if (githubProfile!['location'] != null) profile['location'] = githubProfile!['location'];
      if (githubProfile!['bio'] != null) profile['summary'] = githubProfile!['bio'];
    }

    // Override with LinkedIn data (more authoritative)
    if (linkedinProfile != null) {
      final li = linkedinProfile!.toJson();
      for (var entry in li.entries) {
        final v = entry.value;
        // Only override if LinkedIn value is non-empty
        if (v is String && v.isNotEmpty) {
          profile[entry.key] = v;
        } else if (v is List && v.isNotEmpty) {
          profile[entry.key] = v;
        } else if (v is Map && v.isNotEmpty) {
          profile[entry.key] = v;
        }
      }
    }

    // Override with manual data (user's explicit typed input — highest priority)
    if (manualProfile != null) {
      for (var entry in manualProfile!.entries) {
        final v = entry.value;
        // Only override if user actually typed something
        if (v is String && v.isNotEmpty) {
          profile[entry.key] = v;
        } else if (v is List && v.isNotEmpty) {
          profile[entry.key] = v;
        } else if (v is Map && v.isNotEmpty) {
          profile[entry.key] = v;
        }
      }
    }

    if (githubUrl.isNotEmpty) profile['github'] = githubUrl;
    if (certificates.isNotEmpty) {
      profile['certifications'] = certificates.map((c) => {
        'name': c.certName, 'issuer': c.issuer, 'date': c.issueDate,
      }).toList();
    }
    return profile;
  }
}
