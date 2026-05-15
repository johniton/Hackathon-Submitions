/// app_session.dart
///
/// Lightweight singleton that stores the logged-in user's basic info
/// after a successful login. All features read from here to get the
/// current user's numeric ID (from the custom `users` table).

class AppSession {
  AppSession._();
  static final instance = AppSession._();

  String? _userId;
  String? _userName;
  String? _userEmail;
  String? _avatarInitials;

  String? get userId         => _userId;
  String? get userName       => _userName;
  String? get userEmail      => _userEmail;
  String? get avatarInitials => _avatarInitials;

  bool get isLoggedIn => _userId != null;

  void login({
    required String userId,
    required String name,
    required String email,
  }) {
    _userId         = userId;
    _userName       = name;
    _userEmail      = email;
    _avatarInitials = name.isNotEmpty ? name[0].toUpperCase() : 'U';
  }

  void logout() {
    _userId         = null;
    _userName       = null;
    _userEmail      = null;
    _avatarInitials = null;
  }
}
