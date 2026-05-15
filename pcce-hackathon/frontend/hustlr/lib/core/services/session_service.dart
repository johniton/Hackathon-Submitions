/// lib/core/services/session_service.dart
/// Stores the logged-in user or company identity in SharedPreferences.

import 'package:shared_preferences/shared_preferences.dart';

class SessionService {
  static const _keyId = 'session_id';
  static const _keyName = 'session_name';
  static const _keyEmail = 'session_email';
  static const _keyRole = 'session_role'; // 'user' or 'company'

  static Future<void> save({
    required String id,
    required String name,
    required String email,
    required String role,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyId, id);
    await prefs.setString(_keyName, name);
    await prefs.setString(_keyEmail, email);
    await prefs.setString(_keyRole, role);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyId);
    await prefs.remove(_keyName);
    await prefs.remove(_keyEmail);
    await prefs.remove(_keyRole);
  }

  static Future<String?> getId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyId);
  }

  static Future<String?> getName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyName);
  }

  static Future<String?> getEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyEmail);
  }

  static Future<String?> getRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyRole);
  }

  static Future<bool> isLoggedIn() async {
    final id = await getId();
    return id != null && id.isNotEmpty;
  }

  static Future<bool> isCompany() async {
    final role = await getRole();
    return role == 'company';
  }
}
