import 'package:appmetrica_plugin/appmetrica_plugin.dart';
import 'package:flutter/foundation.dart';

/// События и параметры — по ТЗ (плоские ключи: game_name, source, item_id, type, price).
class AnalyticsService {
  AnalyticsService._();

  static const _apiKey =
      String.fromEnvironment('APPMETRICA_API_KEY', defaultValue: '');

  static bool _activated = false;

  static bool get _isSupportedPlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  static Future<void> init() async {
    if (_activated || !_isSupportedPlatform || _apiKey.isEmpty) return;
    try {
      await AppMetrica.activate(AppMetricaConfig(_apiKey));
      _activated = true;
    } catch (_) {}
  }

  static Future<void> _reportEvent(String name) async {
    if (!_activated) return;
    try {
      await AppMetrica.reportEvent(name);
    } catch (_) {}
  }

  static Future<void> _reportWithMap(
    String name,
    Map<String, Object> params,
  ) async {
    if (!_activated) return;
    try {
      await AppMetrica.reportEventWithMap(name, params);
    } catch (_) {}
  }

  static Future<void> reportGameStart(String gameName) =>
      _reportWithMap('game_start', {'game_name': gameName});

  static Future<void> reportGameWin(String gameName) =>
      _reportWithMap('game_win', {'game_name': gameName});

  static Future<void> reportGameLoss(String gameName) =>
      _reportWithMap('game_loss', {'game_name': gameName});

  /// bet_change: game_name + размер ставки (расширение к ТЗ).
  static Future<void> reportBetChange(String gameName, int bet) =>
      _reportWithMap('bet_change', {
        'game_name': gameName,
        'bet': bet,
      });

  static Future<void> reportPaywallView(String source) =>
      _reportWithMap('paywall_view', {'source': source});

  static Future<void> reportPaywallClose(String source) =>
      _reportWithMap('paywall_close', {'source': source});

  static Future<void> reportPurchaseClick({
    required String itemId,
    required String type,
  }) =>
      _reportWithMap('purchase_click', {
        'item_id': itemId,
        'type': type,
      });

  static Future<void> reportPurchaseSuccess({
    required String itemId,
    required num price,
    required String type,
  }) =>
      _reportWithMap('purchase_success', {
        'item_id': itemId,
        'price': price,
        'type': type,
      });

  static Future<void> reportPurchaseError({
    required String itemId,
    required String type,
  }) =>
      _reportWithMap('purchase_error', {
        'item_id': itemId,
        'type': type,
      });

  static Future<void> reportSettingsOpen() => _reportEvent('settings_open');

  static Future<void> reportAppClose() => _reportEvent('app_close');
}
