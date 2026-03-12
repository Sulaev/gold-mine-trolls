import 'package:shared_preferences/shared_preferences.dart';

class DailyBonusService {
  DailyBonusService._();

  static const _lastClaimDateKey = 'daily_bonus_last_claim_date';
  static const _hasClaimedWelcomeBonusKey = 'daily_bonus_has_claimed_welcome';
  static const _welcomeBonusAmount = 10000;
  static const _dailyBonusAmount = 1000;

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
    final hasClaimedWelcome = prefs.getBool(_hasClaimedWelcomeBonusKey) ?? false;
    return hasClaimedWelcome ? _dailyBonusAmount : _welcomeBonusAmount;
  }

  static Future<int?> claimTodayBonus() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _dateKey(DateTime.now());
    if (prefs.getString(_lastClaimDateKey) == today) return null;

    final hasClaimedWelcome = prefs.getBool(_hasClaimedWelcomeBonusKey) ?? false;
    final amount = hasClaimedWelcome ? _dailyBonusAmount : _welcomeBonusAmount;

    await prefs.setString(_lastClaimDateKey, today);
    await prefs.setBool(_hasClaimedWelcomeBonusKey, true);
    return amount;
  }
}
