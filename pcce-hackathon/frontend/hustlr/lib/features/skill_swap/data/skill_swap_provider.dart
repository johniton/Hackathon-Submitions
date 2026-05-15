/// skill_swap_provider.dart
///
/// ChangeNotifier that holds the current user's Skill Swap profile
/// and surfaces async loading state to the UI.
/// Wire it up at the app level (or at the SkillSwap route level) via
/// ChangeNotifierProvider.

import 'package:flutter/foundation.dart';
import 'package:hustlr/features/skill_swap/domain/models/skill_swap_models.dart';
import 'package:hustlr/features/skill_swap/data/skill_swap_repository.dart';

class SkillSwapProvider extends ChangeNotifier {
  final _repo = SkillSwapRepository.instance;

  SkillSwapUser? _myProfile;
  List<SwapMatch> _suggestedMatches = [];
  List<SwapMatch> _pendingRequests = [];
  List<SwapMatch> _activeSwaps = [];
  List<SwapSession> _sessions = [];
  List<SwapBadge> _badges = [];
  bool _loading = false;
  String? _error;

  SkillSwapUser? get myProfile => _myProfile;
  List<SwapMatch> get suggestedMatches => _suggestedMatches;
  List<SwapMatch> get pendingRequests => _pendingRequests;
  List<SwapMatch> get activeSwaps => _activeSwaps;
  List<SwapSession> get sessions => _sessions;
  List<SwapBadge> get badges => _badges;
  bool get loading => _loading;
  String? get error => _error;

  int get pendingRatingsCount => _sessions.where((s) => s.needsRating).length;

  // ── Retrieve the current user's ID from the Supabase custom users table ──────
  /// Returns the numeric ID stored in the 'users' table (email/password auth).
  /// The login page stores it in shared_preferences; here we get it via Supabase.
  static Future<String?> resolveCurrentUserId() async {
    // The login page uses email+password, not Supabase Auth.
    // We expose a static call so callers can fetch from shared_preferences.
    // See SkillSwapProvider.of(context).myProfile?.id for the resolved value.
    return null; // Overridden by the UI via init(userId, name, avatar)
  }

  // ── Initialise (call once on entering the Skill Swap section) ────────────────
  Future<void> init({
    required String userId,
    required String name,
    required String avatarInitials,
    String city = 'India',
  }) async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      // 1. Ensure profile exists (creates it on first login to skill swap)
      _myProfile = await _repo.ensureProfile(
        userId: userId,
        name: name,
        avatarInitials: avatarInitials,
        city: city,
      );

      // Always use the DB's stored user_id (may differ from login id type)
      await _refreshAll(_myProfile!.id);
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> _refreshAll(String userId) async {
    final results = await Future.wait([
      _repo.getSuggestedMatches(userId),
      _repo.getPendingRequests(userId),
      _repo.getActiveSwaps(userId),
      _repo.getSessionHistory(userId),
      _repo.getBadges(userId),
    ]);

    _suggestedMatches = results[0] as List<SwapMatch>;
    _pendingRequests  = results[1] as List<SwapMatch>;
    _activeSwaps      = results[2] as List<SwapMatch>;
    _sessions         = results[3] as List<SwapSession>;
    _badges           = results[4] as List<SwapBadge>;
  }

  // ── Refresh everything ───────────────────────────────────────────────────────
  Future<void> refresh() async {
    if (_myProfile == null) return;
    _loading = true;
    notifyListeners();
    try {
      await _refreshAll(_myProfile!.id);
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  // ── Update skills ────────────────────────────────────────────────────────────
  Future<void> updateSkills({
    required List<String> skillsToOffer,
    required List<String> skillsWanted,
    String? city,
  }) async {
    if (_myProfile == null) return;
    try {
      _myProfile = await _repo.updateSkills(
        userId:        _myProfile!.id,
        skillsToOffer: skillsToOffer,
        skillsWanted:  skillsWanted,
        city:          city,
      );
      // Re-run matching with updated skills
      _suggestedMatches = await _repo.getSuggestedMatches(_myProfile!.id);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  // ── Connect with a match ─────────────────────────────────────────────────────
  Future<void> connectMatch(SwapMatch match) async {
    if (_myProfile == null) return;
    await _repo.connectMatch(userId: _myProfile!.id, match: match);
    // Remove from suggested
    _suggestedMatches.removeWhere((m) => m.peer.id == match.peer.id);
    await refresh();
  }

  // ── Accept Request ───────────────────────────────────────────────────────────
  Future<void> acceptRequest(SwapMatch match) async {
    if (_myProfile == null) return;
    await _repo.acceptRequest(match.id);
    await refresh();
  }

  // ── Skip a match ─────────────────────────────────────────────────────────────
  Future<void> skipMatch(SwapMatch match) async {
    if (_myProfile == null) return;
    await _repo.skipMatch(userId: _myProfile!.id, peerId: match.peer.id);
    _suggestedMatches.removeWhere((m) => m.peer.id == match.peer.id);
    notifyListeners();
  }

  // ── Book session ─────────────────────────────────────────────────────────────
  Future<SwapSession> bookSession({
    required SwapMatch match,
    required DateTime scheduledAt,
    required int durationMinutes,
    required SessionMode mode,
    required String topic,
    String? meetLink,
  }) async {
    final session = await _repo.bookSession(
      matchId:         match.id,
      hostUserId:      _myProfile!.id,
      peerUserId:      match.peer.id,
      scheduledAt:     scheduledAt,
      durationMinutes: durationMinutes,
      mode:            mode,
      topic:           topic,
      meetLink:        meetLink,
    );
    _sessions.insert(0, session);
    notifyListeners();
    return session;
  }

  // ── Submit rating ─────────────────────────────────────────────────────────────
  Future<void> submitRating({
    required int sessionId,
    required double rating,
    String? feedback,
  }) async {
    if (_myProfile == null) return;
    await _repo.submitRating(
      sessionId: sessionId,
      raterId:   _myProfile!.id,
      rating:    rating,
      feedback:  feedback,
    );
    await refresh();
  }
}
