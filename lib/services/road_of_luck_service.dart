import 'package:shared_preferences/shared_preferences.dart';

class RoadOfLuckService {
  RoadOfLuckService._();

  static const _currentStepKey = 'road_of_luck_current_step';
  static const totalSteps = 6;

  static Future<int> getCurrentStep() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getInt(_currentStepKey) ?? 0;
    return value.clamp(0, totalSteps - 1);
  }

  static Future<int> advanceStep() async {
    final prefs = await SharedPreferences.getInstance();
    final current = await getCurrentStep();
    final next = (current + 1) % totalSteps;
    await prefs.setInt(_currentStepKey, next);
    return next;
  }

  static Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_currentStepKey, 0);
  }
}
