import 'package:shared_preferences/shared_preferences.dart';

/// Manages learning streak tracking for the Learn Skills feature.
///
/// HOW STREAKS WORK:
/// - A "streak day" is counted when the user marks at least one topic/subtopic
///   as complete during a calendar day.
/// - If the user completes something today → streak continues / starts.
/// - If the user misses a day (no activity yesterday) → streak resets to 1.
/// - If the user already logged activity today → streak count does not
///   increment again (one increment per day).
/// - The longest ever streak is also tracked separately.
class StreakService {
  static const _keyCurrentStreak = 'learn_streak_current';
  static const _keyLongestStreak = 'learn_streak_longest';
  static const _keyLastActivityDate = 'learn_streak_last_date';
  static const _keyTotalTopicsCompleted = 'learn_streak_total_topics';

  /// Records a learning activity (topic/subtopic marked complete).
  /// Increments streak if this is the first activity of today.
  /// Returns the updated [StreakData].
  static Future<StreakData> recordActivity() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final todayStr = _dateKey(now);

    final lastDateStr = prefs.getString(_keyLastActivityDate);
    int current = prefs.getInt(_keyCurrentStreak) ?? 0;
    int longest = prefs.getInt(_keyLongestStreak) ?? 0;
    int total = prefs.getInt(_keyTotalTopicsCompleted) ?? 0;

    total++;

    if (lastDateStr == null) {
      // First ever activity
      current = 1;
    } else if (lastDateStr == todayStr) {
      // Already recorded today — don't change streak count
    } else {
      final lastDate = DateTime.parse(lastDateStr);
      final yesterday = DateTime(now.year, now.month, now.day - 1);
      final lastDay = DateTime(lastDate.year, lastDate.month, lastDate.day);

      if (lastDay == yesterday) {
        // Consecutive day — increment streak
        current++;
      } else {
        // Missed one or more days — reset streak
        current = 1;
      }
    }

    if (current > longest) longest = current;

    await prefs.setInt(_keyCurrentStreak, current);
    await prefs.setInt(_keyLongestStreak, longest);
    await prefs.setString(_keyLastActivityDate, todayStr);
    await prefs.setInt(_keyTotalTopicsCompleted, total);

    return StreakData(
      currentStreak: current,
      longestStreak: longest,
      lastActivityDate: now,
      totalTopicsCompleted: total,
    );
  }

  /// Loads the current streak data without modifying it.
  static Future<StreakData> load() async {
    final prefs = await SharedPreferences.getInstance();
    final lastDateStr = prefs.getString(_keyLastActivityDate);
    final current = prefs.getInt(_keyCurrentStreak) ?? 0;
    final longest = prefs.getInt(_keyLongestStreak) ?? 0;
    final total = prefs.getInt(_keyTotalTopicsCompleted) ?? 0;

    // Check if streak has expired (no activity yesterday or today)
    int activeStreak = current;
    if (lastDateStr != null && current > 0) {
      final lastDate = DateTime.parse(lastDateStr);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));
      final lastDay = DateTime(lastDate.year, lastDate.month, lastDate.day);

      if (lastDay.isBefore(yesterday)) {
        // Streak broken — show 0 (but don't write yet, only on next activity)
        activeStreak = 0;
      }
    }

    return StreakData(
      currentStreak: activeStreak,
      longestStreak: longest,
      lastActivityDate: lastDateStr != null
          ? DateTime.tryParse(lastDateStr)
          : null,
      totalTopicsCompleted: total,
    );
  }

  static String _dateKey(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
}

/// Snapshot of the user's current streak state.
class StreakData {
  final int currentStreak;
  final int longestStreak;
  final DateTime? lastActivityDate;
  final int totalTopicsCompleted;

  const StreakData({
    required this.currentStreak,
    required this.longestStreak,
    required this.lastActivityDate,
    required this.totalTopicsCompleted,
  });

  bool get isActiveToday {
    if (lastActivityDate == null) return false;
    final now = DateTime.now();
    return lastActivityDate!.year == now.year &&
        lastActivityDate!.month == now.month &&
        lastActivityDate!.day == now.day;
  }

  String get streakEmoji {
    if (currentStreak == 0) return '❄️';
    if (currentStreak < 3) return '🔥';
    if (currentStreak < 7) return '🔥🔥';
    if (currentStreak < 30) return '🔥🔥🔥';
    return '🏆';
  }
}
