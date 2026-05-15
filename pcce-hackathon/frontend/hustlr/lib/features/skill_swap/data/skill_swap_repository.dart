/// skill_swap_repository.dart
///
/// Fully dynamic repository — all data comes from Supabase.
/// Auth note: this app uses a custom `users` table (not Supabase Auth).
/// The caller must supply [currentUserId] (the integer PK from the users table).

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hustlr/features/skill_swap/domain/models/skill_swap_models.dart';

class SkillSwapRepository {
  SkillSwapRepository._();
  static final instance = SkillSwapRepository._();

  SupabaseClient get _db => Supabase.instance.client;

  // ── Ensure profile exists (call on first visit to skill swap) ────────────────
  /// Creates a skill_swap_users row if one doesn't exist yet.
  Future<SkillSwapUser> ensureProfile({
    required String userId,
    required String name,
    required String avatarInitials,
    String city = 'India',
  }) async {
    // Try fetching existing profile
    final existing = await _db
        .from('skill_swap_users')
        .select()
        .eq('user_id', userId)
        .maybeSingle();

    if (existing != null) {
      return SkillSwapUser.fromJson(existing);
    }

    // Create new profile
    final inserted = await _db
        .from('skill_swap_users')
        .insert({
          'user_id':         userId,
          'name':            name,
          'avatar_initials': avatarInitials,
          'city':            city,
          'skills_to_offer': <String>[],
          'skills_wanted':   <String>[],
        })
        .select()
        .single();

    return SkillSwapUser.fromJson(inserted);
  }

  // ── Fetch current user profile ───────────────────────────────────────────────
  Future<SkillSwapUser?> getMyProfile(String userId) async {
    final data = await _db
        .from('skill_swap_users')
        .select()
        .eq('user_id', userId)
        .maybeSingle();

    if (data == null) return null;
    return SkillSwapUser.fromJson(data);
  }

  // ── Update skills ────────────────────────────────────────────────────────────
  Future<SkillSwapUser> updateSkills({
    required String userId,
    required List<String> skillsToOffer,
    required List<String> skillsWanted,
    String? city,
  }) async {
    final payload = <String, dynamic>{
      'skills_to_offer': skillsToOffer,
      'skills_wanted':   skillsWanted,
    };
    if (city != null) payload['city'] = city;

    final updated = await _db
        .from('skill_swap_users')
        .update(payload)
        .eq('user_id', userId)
        .select()
        .single();

    return SkillSwapUser.fromJson(updated);
  }

  // ── Suggested matches (via Supabase RPC) ─────────────────────────────────────
  Future<List<SwapMatch>> getSuggestedMatches(String userId) async {
    final rows = await _db.rpc(
      'find_skill_matches',
      params: {'p_user_id': userId},
    ) as List<dynamic>;

    return rows
        .cast<Map<String, dynamic>>()
        .where((r) =>
            (r['teaching_skill'] as String?)?.isNotEmpty == true &&
            (r['learning_skill'] as String?)?.isNotEmpty == true)
        .map(SwapMatch.fromRpcJson)
        .toList();
  }

  // ── Active swaps ─────────────────────────────────────────────────────────────
  Future<List<SwapMatch>> getActiveSwaps(String userId) async {
    final asInitiator = await _db
        .from('swap_matches')
        .select('id, user_id, peer_id, teaching_skill, learning_skill, match_score, status, created_at')
        .eq('user_id', userId)
        .eq('status', 'active') as List<dynamic>;

    final asReceiver = await _db
        .from('swap_matches')
        .select('id, user_id, peer_id, teaching_skill, learning_skill, match_score, status, created_at')
        .eq('peer_id', userId)
        .eq('status', 'active') as List<dynamic>;

    final peerIds = <String>{};
    for (final row in asInitiator) peerIds.add(row['peer_id'] as String);
    for (final row in asReceiver) peerIds.add(row['user_id'] as String);

    final Map<String, dynamic> peerProfiles = {};
    if (peerIds.isNotEmpty) {
      final profiles = await _db
          .from('skill_swap_users')
          .select('user_id, name, avatar_initials, city, skills_to_offer, skills_wanted, rating, sessions_completed')
          .inFilter('user_id', peerIds.toList()) as List<dynamic>;
      for (final p in profiles) {
        peerProfiles[p['user_id'] as String] = p;
      }
    }

    final matches = <SwapMatch>[];

    for (final row in asInitiator) {
      final r = Map<String, dynamic>.from(row as Map);
      r['peer'] = peerProfiles[r['peer_id'] as String];
      if (r['peer'] != null) {
        matches.add(SwapMatch.fromJson(r));
      }
    }

    for (final row in asReceiver) {
      final r = Map<String, dynamic>.from(row as Map);
      r['peer'] = peerProfiles[r['user_id'] as String];
      if (r['peer'] != null) {
        final match = SwapMatch.fromJson(r);
        matches.add(SwapMatch(
          id: match.id,
          peer: match.peer,
          teachingSkill: match.learningSkill, // The peer's learning is our teaching
          learningSkill: match.teachingSkill, // The peer's teaching is our learning
          matchScore: match.matchScore,
          status: match.status,
        ));
      }
    }

    return matches;
  }

  // ── Pending Requests ─────────────────────────────────────────────────────────
  Future<List<SwapMatch>> getPendingRequests(String userId) async {
    final asReceiver = await _db
        .from('swap_matches')
        .select('id, user_id, peer_id, teaching_skill, learning_skill, match_score, status, created_at')
        .eq('peer_id', userId)
        .eq('status', 'pending') as List<dynamic>;

    final peerIds = <String>{};
    for (final row in asReceiver) peerIds.add(row['user_id'] as String);

    final Map<String, dynamic> peerProfiles = {};
    if (peerIds.isNotEmpty) {
      final profiles = await _db
          .from('skill_swap_users')
          .select('user_id, name, avatar_initials, city, skills_to_offer, skills_wanted, rating, sessions_completed')
          .inFilter('user_id', peerIds.toList()) as List<dynamic>;
      for (final p in profiles) {
        peerProfiles[p['user_id'] as String] = p;
      }
    }

    final matches = <SwapMatch>[];

    for (final row in asReceiver) {
      final r = Map<String, dynamic>.from(row as Map);
      r['peer'] = peerProfiles[r['user_id'] as String];
      if (r['peer'] != null) {
        final match = SwapMatch.fromJson(r);
        matches.add(SwapMatch(
          id: match.id,
          peer: match.peer,
          teachingSkill: match.learningSkill, // The peer's learning is our teaching
          learningSkill: match.teachingSkill, // The peer's teaching is our learning
          matchScore: match.matchScore,
          status: match.status,
        ));
      }
    }

    return matches;
  }

  // ── Connect (accept a suggested match → insert into swap_matches as pending) ────────────
  Future<void> connectMatch({
    required String userId,
    required SwapMatch match,
  }) async {
    await _db.from('swap_matches').insert({
      'user_id':        userId,
      'peer_id':        match.peer.id,
      'teaching_skill': match.teachingSkill,
      'learning_skill': match.learningSkill,
      'match_score':    match.matchScore,
      'status':         'pending',
    });
  }

  // ── Accept Request ───────────────────────────────────────────────────────────
  Future<void> acceptRequest(int matchId) async {
    await _db.from('swap_matches').update({
      'status': 'active',
    }).eq('id', matchId);
  }

  // ── Skip a match (track it so it doesn't reappear) ───────────────────────────
  Future<void> skipMatch({
    required String userId,
    required String peerId,
  }) async {
    await _db.from('swap_matches').insert({
      'user_id':        userId,
      'peer_id':        peerId,
      'teaching_skill': '',
      'learning_skill': '',
      'match_score':    0.0,
      'status':         'skipped',
    });
  }

  // ── Session history ───────────────────────────────────────────────────────────
  Future<List<SwapSession>> getSessionHistory(String userId) async {
    final rows = await _db
        .from('swap_sessions')
        .select('''
          id, match_id, scheduled_at, duration_minutes, mode,
          meet_link, topic_covered, attendance,
          host_rating, peer_rating,
          host_user_id, peer_user_id
        ''')
        .or('host_user_id.eq.$userId,peer_user_id.eq.$userId')
        .order('scheduled_at', ascending: false) as List<dynamic>;

    final peerIds = <String>{};
    for (final row in rows) {
      peerIds.add(row['host_user_id'] as String);
      peerIds.add(row['peer_user_id'] as String);
    }
    peerIds.remove(userId);

    final Map<String, dynamic> peerProfiles = {};
    if (peerIds.isNotEmpty) {
      final profiles = await _db
          .from('skill_swap_users')
          .select('user_id, name, avatar_initials, city, skills_to_offer, skills_wanted, rating, sessions_completed')
          .inFilter('user_id', peerIds.toList()) as List<dynamic>;
      for (final p in profiles) {
        peerProfiles[p['user_id'] as String] = p;
      }
    }

    return rows.cast<Map<String, dynamic>>().map((row) {
      final r = Map<String, dynamic>.from(row);
      final isHost = (r['host_user_id'] as String) == userId;
      final peerId = isHost ? r['peer_user_id'] as String : r['host_user_id'] as String;
      
      r['peer'] = peerProfiles[peerId] ?? {
        'user_id': peerId, 'name': 'Unknown User', 'avatar_initials': 'U',
        'city': 'Unknown', 'skills_to_offer': [], 'skills_wanted': [],
        'rating': 0.0, 'sessions_completed': 0
      };
      
      return SwapSession.fromJson(r, isHost: isHost);
    }).toList();
  }

  // ── Book a session ────────────────────────────────────────────────────────────
  Future<SwapSession> bookSession({
    required int matchId,
    required String hostUserId,
    required String peerUserId,
    required DateTime scheduledAt,
    required int durationMinutes,
    required SessionMode mode,
    required String topic,
    String? meetLink,
  }) async {
    final peerProfile = await _db
        .from('skill_swap_users')
        .select()
        .eq('user_id', peerUserId)
        .single();

    final inserted = await _db
        .from('swap_sessions')
        .insert({
          'match_id':         matchId,
          'host_user_id':     hostUserId,
          'peer_user_id':     peerUserId,
          'scheduled_at':     scheduledAt.toIso8601String(),
          'duration_minutes': durationMinutes,
          'mode':             mode == SessionMode.video ? 'video' : 'chat',
          'meet_link':        meetLink,
          'topic_covered':    topic,
        })
        .select()
        .single();

    // Merge peer profile into the row so fromJson works
    final merged = Map<String, dynamic>.from(inserted);
    merged['peer'] = peerProfile;

    return SwapSession.fromJson(merged, isHost: true);
  }

  // ── Submit rating ─────────────────────────────────────────────────────────────
  Future<void> submitRating({
    required int sessionId,
    required String raterId,
    required double rating,
    String? feedback,
  }) async {
    // Determine if this rater is the host or the peer
    final session = await _db
        .from('swap_sessions')
        .select('host_user_id, peer_user_id')
        .eq('id', sessionId)
        .single();

    final isHost = (session['host_user_id'] as String) == raterId;
    final updatePayload = <String, dynamic>{
      'attendance': 'attended',
    };

    if (isHost) {
      updatePayload['host_rating']   = rating;
      updatePayload['host_feedback'] = feedback;
    } else {
      updatePayload['peer_rating']   = rating;
      updatePayload['peer_feedback'] = feedback;
    }

    await _db
        .from('swap_sessions')
        .update(updatePayload)
        .eq('id', sessionId);
  }

  // ── Badges ────────────────────────────────────────────────────────────────────
  Future<List<SwapBadge>> getBadges(String userId) async {
    // Fetch all badge definitions
    final defs = await _db
        .from('swap_badge_definitions')
        .select() as List<dynamic>;

    // Fetch badges earned by this user
    final earned = await _db
        .from('user_badges')
        .select('badge_id')
        .eq('user_id', userId) as List<dynamic>;

    final earnedIds = earned
        .cast<Map<String, dynamic>>()
        .map((r) => r['badge_id'] as String)
        .toSet();

    return defs
        .cast<Map<String, dynamic>>()
        .map((d) => SwapBadge.fromJson(d, earnedIds.contains(d['id'])))
        .toList();
  }

  // ── Stats helper ──────────────────────────────────────────────────────────────
  Future<int> getPendingRatingsCount(String userId) async {
    final sessions = await getSessionHistory(userId);
    return sessions.where((s) => s.needsRating).length;
  }
}
