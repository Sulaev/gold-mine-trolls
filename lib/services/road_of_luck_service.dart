import 'package:shared_preferences/shared_preferences.dart';

class RoadOfLuckService {
  RoadOfLuckService._();

  static const _currentStepKey = 'road_of_luck_current_step';
  static const totalSteps = 6;

  /// Порядок пути по стрелкам: 0 -> 1 -> 3 -> 2 -> 4 -> 5
  static const _pathOrder = [0, 1, 3, 2, 4, 5];

  static Future<int> getCurrentStep() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getInt(_currentStepKey) ?? 0;
    return value.clamp(0, totalSteps - 1);
  }

  static Future<int> advanceStep() async {
    final prefs = await SharedPreferences.getInstance();
    final current = await getCurrentStep();
    final pathIndex = _pathOrder.indexOf(current);
    final nextPathIndex = (pathIndex + 1) % totalSteps;
    final next = _pathOrder[nextPathIndex];
    await prefs.setInt(_currentStepKey, next);
    return next;
  }

}
