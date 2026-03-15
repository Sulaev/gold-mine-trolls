import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  SettingsService._();

  static const _soundEnabledKey = 'settings_sound_enabled';
  static const _musicEnabledKey = 'settings_music_enabled';
  static const _notificationEnabledKey = 'settings_notification_enabled';
  static const _vibrationEnabledKey = 'settings_vibration_enabled';

  static final ValueNotifier<bool> soundEnabledNotifier =
      ValueNotifier<bool>(true);
  static final ValueNotifier<bool> musicEnabledNotifier =
      ValueNotifier<bool>(true);
  static final ValueNotifier<bool> notificationEnabledNotifier =
      ValueNotifier<bool>(true);
  static final ValueNotifier<bool> vibrationEnabledNotifier =
      ValueNotifier<bool>(true);

  static bool get soundEnabled => soundEnabledNotifier.value;
  static bool get musicEnabled => musicEnabledNotifier.value;
  static bool get notificationEnabled => notificationEnabledNotifier.value;
  static bool get vibrationEnabled => vibrationEnabledNotifier.value;

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    soundEnabledNotifier.value = prefs.getBool(_soundEnabledKey) ?? true;
    musicEnabledNotifier.value = prefs.getBool(_musicEnabledKey) ?? true;
    notificationEnabledNotifier.value =
        prefs.getBool(_notificationEnabledKey) ?? true;
    vibrationEnabledNotifier.value =
        prefs.getBool(_vibrationEnabledKey) ?? true;
  }

  static Future<void> setSoundEnabled(bool value) async {
    if (soundEnabledNotifier.value == value) return;
    soundEnabledNotifier.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_soundEnabledKey, value);
  }

  static Future<void> setMusicEnabled(bool value) async {
    if (musicEnabledNotifier.value == value) return;
    musicEnabledNotifier.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_musicEnabledKey, value);
  }

  static Future<void> setNotificationEnabled(bool value) async {
    if (notificationEnabledNotifier.value == value) return;
    notificationEnabledNotifier.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notificationEnabledKey, value);
  }

  static Future<void> setVibrationEnabled(bool value) async {
    if (vibrationEnabledNotifier.value == value) return;
    vibrationEnabledNotifier.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_vibrationEnabledKey, value);
  }

  static void hapticLightImpact() {
    if (vibrationEnabledNotifier.value) HapticFeedback.lightImpact();
  }

  static void hapticSelectionClick() {
    if (vibrationEnabledNotifier.value) HapticFeedback.selectionClick();
  }

  static void hapticMediumImpact() {
    if (vibrationEnabledNotifier.value) HapticFeedback.mediumImpact();
  }

  static void hapticHeavyImpact() {
    if (vibrationEnabledNotifier.value) HapticFeedback.heavyImpact();
  }
}
