import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _balanceKey = 'balance';
const _lastBetKey = 'gold_vein_last_bet';
const _minersWheelLastWinKey = 'miners_wheel_last_win';

class BalanceService {
  static final ValueNotifier<int> balanceNotifier = ValueNotifier(0);
  static bool _initialized = false;

  /// Load balance from storage into notifier. Call at app start.
  static Future<void> init() async {
    if (_initialized) return;
    final value = await getBalance();
    balanceNotifier.value = value;
    _initialized = true;
  }

  static Future<int> getBalance() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_balanceKey) ?? 0;
  }

  static Future<void> addBalance(int amount) async {
    final current = await getBalance();
    await setBalance(current + amount);
  }

  static Future<void> setBalance(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_balanceKey, value);
    balanceNotifier.value = value;
  }

  static Future<int?> getLastBet() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_lastBetKey);
  }

  static Future<void> setLastBet(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastBetKey, value);
  }

  static Future<int?> getMinersWheelLastWin() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_minersWheelLastWinKey);
  }

  static Future<void> setMinersWheelLastWin(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_minersWheelLastWinKey, value);
  }
}
