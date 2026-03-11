import 'package:appmetrica_plugin/appmetrica_plugin.dart';
import 'package:flutter/foundation.dart';

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

  static Future<void> _reportScopedEvent(
    String name,
    String scope, {
    Map<String, Object?> params = const {},
  }) async {
    if (!_activated) return;
    try {
      await AppMetrica.reportEventWithMap(name, {
        scope: params,
      });
    } catch (_) {}
  }

  static Future<void> reportGameStart(String gameName) =>
      _reportScopedEvent('game_start', gameName);

  static Future<void> reportGameWin(String gameName) =>
      _reportScopedEvent('game_win', gameName);

  static Future<void> reportGameLoss(String gameName) =>
      _reportScopedEvent('game_loss', gameName);

  static Future<void> reportBetChange(String gameName, int bet) =>
      _reportScopedEvent('bet_change', gameName, params: {'bet': bet});

  static Future<void> reportPaywallView(String source) =>
      _reportScopedEvent('paywall_view', source);

  static Future<void> reportPaywallClose(String source) =>
      _reportScopedEvent('paywall_close', source);

  static Future<void> reportPurchaseClick({
    required String itemId,
    required String type,
  }) =>
      _reportScopedEvent(
        'purchase_click',
        itemId,
        params: {'item_id': itemId, 'type': type},
      );

  static Future<void> reportPurchaseSuccess({
    required String itemId,
    required num price,
    required String type,
  }) =>
      _reportScopedEvent(
        'purchase_success',
        itemId,
        params: {'item_id': itemId, 'price': price, 'type': type},
      );

  static Future<void> reportPurchaseError({
    required String itemId,
    required String type,
  }) =>
      _reportScopedEvent(
        'purchase_error',
        itemId,
        params: {'item_id': itemId, 'type': type},
      );

  static Future<void> reportSettingsOpen() => _reportEvent('settings_open');

  static Future<void> reportAppClose() => _reportEvent('app_close');
}
