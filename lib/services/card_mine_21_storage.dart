import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

const _savedGameKey = 'card_mine_21_saved_game';

class CardMine21Storage {
  static Future<void> saveGame(Map<String, dynamic> state) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_savedGameKey, jsonEncode(state));
  }

  static Future<Map<String, dynamic>?> loadGame() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_savedGameKey);
    if (json == null) return null;
    try {
      return Map<String, dynamic>.from(jsonDecode(json) as Map);
    } catch (_) {
      return null;
    }
  }

  static Future<void> clearGame() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_savedGameKey);
  }
}
