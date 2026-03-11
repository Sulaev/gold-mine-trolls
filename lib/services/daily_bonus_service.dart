import 'package:shared_preferences/shared_preferences.dart';

class DailyBonusService {
  DailyBonusService._();

  static const _lastClaimDateKey = 'daily_bonus_last_claim_date';
  static const _nextBonusIndexKey = 'daily_bonus_next_bonus_index';
  static const List<int> _cycle = [
    10000,
    1000,
    2000,
    3000,
    4000,
    5000,
    6000,
    7000,
    8000,
    9000,
  ];

  static String _dateKey(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  static Future<bool> isBonusAvailableToday() async {
    final prefs = await SharedPreferences.getInstance();
    final lastClaimDate = prefs.getString(_lastClaimDateKey);
    return lastClaimDate != _dateKey(DateTime.now());
  }

  static Future<int> getTodayBonusAmount() async {
    final prefs = await SharedPreferences.getInstance();
    final index = (prefs.getInt(_nextBonusIndexKey) ?? 0) % _cycle.length;
    return _cycle[index];
  }

  static Future<int?> claimTodayBonus() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _dateKey(DateTime.now());
    if (prefs.getString(_lastClaimDateKey) == today) return null;

    final index = (prefs.getInt(_nextBonusIndexKey) ?? 0) % _cycle.length;
    final amount = _cycle[index];

    await prefs.setString(_lastClaimDateKey, today);
    await prefs.setInt(_nextBonusIndexKey, (index + 1) % _cycle.length);
    return amount;
  }
}
