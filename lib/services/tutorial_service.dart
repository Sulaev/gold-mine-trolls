import 'package:shared_preferences/shared_preferences.dart';

/// Shared service for app-wide tutorial state.
/// Tutorials show only for new users, once.
class TutorialService {
  static const _appTutorialsCompletedKey = 'app_tutorials_completed';

  /// true = обучение всегда (отладка). false = только новые пользователи (до app_tutorials_completed).
  static const forceTutorialForTesting = false;

  static Future<bool> isTutorialsCompleted() async {
    if (forceTutorialForTesting) return false;
    return isTutorialsCompletedRaw();
  }

  /// Фактическое значение (без учёта forceTutorialForTesting): для логики бонусов.
  static Future<bool> isTutorialsCompletedRaw() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_appTutorialsCompletedKey) ?? false;
  }

  static Future<void> setTutorialsCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_appTutorialsCompletedKey, true);
  }
}
