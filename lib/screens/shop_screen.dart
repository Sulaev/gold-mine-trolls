import 'dart:math';

import 'package:flutter/material.dart';
import 'package:gold_mine_trolls/screens/miners_pass_screen.dart';
import 'package:gold_mine_trolls/services/analytics_service.dart';
import 'package:gold_mine_trolls/services/balance_service.dart';
import 'package:gold_mine_trolls/services/settings_service.dart';
import 'package:gold_mine_trolls/widgets/shop_element_card.dart';
import 'package:gold_mine_trolls/widgets/pressable_button.dart';
import 'package:gold_mine_trolls/widgets/tap_banner.dart';

/// Shop modal — appears over the main screen with darkened background
class ShopScreen extends StatefulWidget {
  const ShopScreen({
    super.key,
    required this.source,
  });

  final String source;

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  bool _purchaseMade = false;

  static const _baseScale = 0.917;
  static const _designWidth = 390.0;
  static const _designHeight = 844.0;

  static const _coinOffers = [
    ('coins_100000', 100000, 0.0),
    ('coins_250000', 250000, 0.0),
    ('coins_500000', 500000, 0.0),
    ('coins_1000000', 1000000, 0.0),
    ('coins_3000000', 3000000, 0.0),
  ];

  @override
  void initState() {
    super.initState();
    AnalyticsService.reportPaywallView(widget.source);
  }

  @override
  void dispose() {
    if (!_purchaseMade) {
      AnalyticsService.reportPaywallClose(widget.source);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      child: Material(
        color: Colors.transparent,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final scale = min(
              constraints.maxWidth / _designWidth,
              constraints.maxHeight / _designHeight,
            ).clamp(0.82, 1.3);
            final s = _baseScale * scale;
            return Stack(
              fit: StackFit.expand,
              children: [
                const ColoredBox(color: Color(0x4D000000)),
                Positioned(
                  top: (47.0 + 24.0) * s,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: SizedBox(
                      width: 75.0 * s,
                      height: 42.0 * s,
                      child: Image.asset(
                        'assets/images/shop/shop_logo.png',
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => Text(
                          'SHOP',
                          style: TextStyle(
                            color: Colors.amber,
                            fontSize: 20 * s,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: (47.0 + 24.0) * s,
                  right: 16.0 * s,
                  child: PressableButton(
                    onTap: () {
                      SettingsService.hapticLightImpact();
                      Navigator.of(context).pop();
                    },
                    child: SizedBox(
                      width: 38.0 * s,
                      height: 38.0 * s,
                      child: Image.asset(
                        'assets/images/shop/btn_close.png',
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => Container(
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close, color: Colors.white, size: 24),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: (110.0 + 24.0) * s,
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: SingleChildScrollView(
                    physics: const NeverScrollableScrollPhysics(),
                    padding: EdgeInsets.only(bottom: 70 * s),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ...List.generate(_coinOffers.length, (i) {
                            return Transform.translate(
                              offset: Offset(0, i > 0 ? -28.0 * s * i : 0),
                              child: ShopElementCard(
                                coins: _coinOffers[i].$2,
                                contentTopOffset: i == 4 ? 3 : 0,
                                showOnlyForYouBanner: i == 4,
                                scale: s,
                                onBuyTap: () async {
                                  SettingsService.hapticLightImpact();
                                  final itemId = _coinOffers[i].$1;
                                  final amount = _coinOffers[i].$2;
                                  final price = _coinOffers[i].$3;
                                  await AnalyticsService.reportPurchaseClick(
                                    itemId: itemId,
                                    type: 'coin',
                                  );
                                  try {
                                    await BalanceService.addBalance(amount);
                                    _purchaseMade = true;
                                    await AnalyticsService.reportPurchaseSuccess(
                                      itemId: itemId,
                                      price: price,
                                      type: 'coin',
                                    );
                                  } catch (_) {
                                    await AnalyticsService.reportPurchaseError(
                                      itemId: itemId,
                                      type: 'coin',
                                    );
                                  }
                                },
                              ),
                            );
                          }),
                          Transform.translate(
                            offset: Offset(0, -120.0 * s),
                            child: SizedBox(
                              width: 311.0 * s,
                              height: 160.0 * s,
                              child: TapBanner(
                                bannerAsset: 'assets/images/shop/banner_miner_pass.png',
                                width: 311.0 * s,
                                height: 160.0 * s,
                                tapScale: 0.855,
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const MinersPassScreen(source: 'shop'),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: EdgeInsets.only(bottom: 16 * s),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'PRIVACY POLICY',
                            style: _shopFooterLinkStyle(s),
                          ),
                          SizedBox(width: 16 * s),
                          Text(
                            'TERMS OF USE',
                            style: _shopFooterLinkStyle(s),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  static TextStyle _shopFooterLinkStyle(double s) {
    return TextStyle(
      fontFamily: 'Gotham',
      fontWeight: FontWeight.w900,
      fontSize: 18 * s,
      height: 1.4,
      letterSpacing: -0.36 * s,
      decoration: TextDecoration.underline,
      decorationColor: Colors.white,
      decorationStyle: TextDecorationStyle.solid,
      decorationThickness: 2.5,
      color: Colors.white,
    );
  }
}
