/// skill_swap_models.dart
///
/// All domain models for the Skill Swap feature.
/// Fully serializable — compatible with Supabase JSON responses.

import 'package:flutter/material.dart';

// ─── Enums ───────────────────────────────────────────────────────────────────

enum SwapStatus { pending, active, completed, disputed, skipped }

enum SessionMode { video, chat }

enum AttendanceStatus { attended, missed, excused }

// ─── Helper ──────────────────────────────────────────────────────────────────

SwapStatus _parseSwapStatus(String? s) {
  switch (s) {
    case 'active':     return SwapStatus.active;
    case 'completed':  return SwapStatus.completed;
    case 'disputed':   return SwapStatus.disputed;
    case 'skipped':    return SwapStatus.skipped;
    default:           return SwapStatus.pending;
  }
}

SessionMode _parseSessionMode(String? s) =>
    s == 'chat' ? SessionMode.chat : SessionMode.video;

AttendanceStatus? _parseAttendance(String? s) {
  switch (s) {
    case 'attended': return AttendanceStatus.attended;
    case 'missed':   return AttendanceStatus.missed;
    case 'excused':  return AttendanceStatus.excused;
    default:         return null;
  }
}

// ─── Models ──────────────────────────────────────────────────────────────────

class SkillSwapUser {
  final String id;               // skill_swap_users.user_id (TEXT/UUID)
  final String name;
  final String avatar;        // initials
  final String city;
  final List<String> skillsToOffer;
  final List<String> skillsWanted;
  final double rating;
  final int sessionsCompleted;

  const SkillSwapUser({
    required this.id,
    required this.name,
    required this.avatar,
    required this.city,
    required this.skillsToOffer,
    required this.skillsWanted,
    required this.rating,
    required this.sessionsCompleted,
  });

  factory SkillSwapUser.fromJson(Map<String, dynamic> json) {
    return SkillSwapUser(
      id:                 (json['user_id'] ?? json['id'] ?? '') as String,
      name:               (json['name'] ?? 'Unknown') as String,
      avatar:             (json['avatar_initials'] ?? json['avatar'] ?? 'U') as String,
      city:               (json['city'] ?? 'India') as String,
      skillsToOffer:      List<String>.from(json['skills_to_offer'] ?? []),
      skillsWanted:       List<String>.from(json['skills_wanted'] ?? []),
      rating:             double.tryParse(json['rating']?.toString() ?? '') ?? 5.0,
      sessionsCompleted:  (json['sessions_completed'] ?? 0) as int,
    );
  }

  /// From the RPC find_skill_matches response which has prefixed column names
  factory SkillSwapUser.fromRpcJson(Map<String, dynamic> json) {
    return SkillSwapUser(
      id:                 (json['peer_user_id'] ?? '') as String,
      name:               (json['peer_name'] ?? 'Unknown') as String,
      avatar:             (json['peer_avatar'] ?? 'U') as String,
      city:               (json['peer_city'] ?? 'India') as String,
      skillsToOffer:      List<String>.from(json['peer_skills_offer'] ?? []),
      skillsWanted:       List<String>.from(json['peer_skills_wanted'] ?? []),
      rating:             double.tryParse(json['peer_rating']?.toString() ?? '') ?? 5.0,
      sessionsCompleted:  (json['peer_sessions'] ?? 0) as int,
    );
  }

  Map<String, dynamic> toJson() => {
    'user_id':             id,
    'name':                name,
    'avatar_initials':     avatar,
    'city':                city,
    'skills_to_offer':     skillsToOffer,
    'skills_wanted':       skillsWanted,
    'rating':              rating,
    'sessions_completed':  sessionsCompleted,
  };

  SkillSwapUser copyWith({
    List<String>? skillsToOffer,
    List<String>? skillsWanted,
    String? city,
    double? rating,
    int? sessionsCompleted,
  }) {
    return SkillSwapUser(
      id: id,
      name: name,
      avatar: avatar,
      city: city ?? this.city,
      skillsToOffer: skillsToOffer ?? this.skillsToOffer,
      skillsWanted: skillsWanted ?? this.skillsWanted,
      rating: rating ?? this.rating,
      sessionsCompleted: sessionsCompleted ?? this.sessionsCompleted,
    );
  }
}

class SwapMatch {
  final int id;               // swap_matches.id
  final SkillSwapUser peer;
  final String teachingSkill; // what the current user teaches the peer
  final String learningSkill; // what the peer teaches the current user
  final double matchScore;    // 0.0 – 1.0
  final SwapStatus status;

  const SwapMatch({
    required this.id,
    required this.peer,
    required this.teachingSkill,
    required this.learningSkill,
    required this.matchScore,
    required this.status,
  });

  /// Build from the RPC `find_skill_matches` result row.
  factory SwapMatch.fromRpcJson(Map<String, dynamic> json) {
    return SwapMatch(
      id:             0,
      peer:           SkillSwapUser.fromRpcJson(json),
      teachingSkill:  (json['teaching_skill'] ?? '') as String,
      learningSkill:  (json['learning_skill'] ?? '') as String,
      matchScore:     double.tryParse(json['match_score']?.toString() ?? '') ?? 0.0,
      status:         SwapStatus.pending,
    );
  }

  /// Build from swap_matches row (joined with skill_swap_users for peer data).
  factory SwapMatch.fromJson(Map<String, dynamic> json) {
    return SwapMatch(
      id:             (json['id'] ?? 0) as int,
      peer:           SkillSwapUser.fromJson(json['peer'] as Map<String, dynamic>),
      teachingSkill:  (json['teaching_skill'] ?? '') as String,
      learningSkill:  (json['learning_skill'] ?? '') as String,
      matchScore:     double.tryParse(json['match_score']?.toString() ?? '') ?? 0.0,
      status:         _parseSwapStatus(json['status'] as String?),
    );
  }

  Map<String, dynamic> toInsertJson({
    required String userId,
    required String peerId,
  }) => {
    'user_id':        userId,
    'peer_id':        peerId,
    'teaching_skill': teachingSkill,
    'learning_skill': learningSkill,
    'match_score':    matchScore,
    'status':         'pending',
  };
}

class SwapSession {
  final int id;
  final int matchId;
  final SkillSwapUser peer;
  final DateTime scheduledAt;
  final int durationMinutes;
  final SessionMode mode;
  final String? meetLink;
  final String topicCovered;
  final AttendanceStatus? attendance; // null = not yet held
  final double? myRating;             // null = not yet rated
  final double? peerRating;

  const SwapSession({
    required this.id,
    required this.matchId,
    required this.peer,
    required this.scheduledAt,
    required this.durationMinutes,
    required this.mode,
    this.meetLink,
    required this.topicCovered,
    this.attendance,
    this.myRating,
    this.peerRating,
  });

  factory SwapSession.fromJson(Map<String, dynamic> json, {required bool isHost}) {
    return SwapSession(
      id:              (json['id'] ?? 0) as int,
      matchId:         (json['match_id'] ?? 0) as int,
      peer:            SkillSwapUser.fromJson(json['peer'] as Map<String, dynamic>),
      scheduledAt:     DateTime.parse(json['scheduled_at'] as String),
      durationMinutes: (json['duration_minutes'] ?? 60) as int,
      mode:            _parseSessionMode(json['mode'] as String?),
      meetLink:        json['meet_link'] as String?,
      topicCovered:    (json['topic_covered'] ?? 'Skill Swap Session') as String,
      attendance:      _parseAttendance(json['attendance'] as String?),
      myRating:        isHost
          ? double.tryParse(json['host_rating']?.toString() ?? '')
          : double.tryParse(json['peer_rating']?.toString() ?? ''),
      peerRating:      isHost
          ? double.tryParse(json['peer_rating']?.toString() ?? '')
          : double.tryParse(json['host_rating']?.toString() ?? ''),
    );
  }

  bool get isPast     => scheduledAt.isBefore(DateTime.now());
  bool get isUpcoming => !isPast;
  bool get needsRating =>
      isPast && attendance == AttendanceStatus.attended && myRating == null;
}

class SwapBadge {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final bool earned;

  const SwapBadge({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.earned,
  });

  factory SwapBadge.fromJson(Map<String, dynamic> def, bool earned) {
    return SwapBadge(
      id:          (def['id'] ?? '') as String,
      title:       (def['title'] ?? '') as String,
      description: (def['description'] ?? '') as String,
      icon:        _iconFromName(def['icon_name'] as String? ?? 'zap'),
      color:       _colorFromHex(def['color_hex'] as String? ?? '#14B8A6'),
      earned:      earned,
    );
  }
}

// ─── Icon / Color helpers ─────────────────────────────────────────────────────

IconData _iconFromName(String name) {
  switch (name) {
    case 'trophy':       return Icons.emoji_events;
    case 'refresh-ccw':  return Icons.refresh;
    case 'star':         return Icons.star;
    case 'zap':
    default:             return Icons.bolt;
  }
}

Color _colorFromHex(String hex) {
  final h = hex.replaceFirst('#', '');
  return Color(int.parse('FF$h', radix: 16));
}
