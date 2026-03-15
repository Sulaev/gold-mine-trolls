import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  static const _scale = 0.917; // 0.873 * 1.05 — всё кроме кнопки закрыть увеличено на 5%
  static const _topPadding = 24.0;
  static double get _shopTitleTop => (47.0 + _topPadding) * _scale;
  static double get _shopTitleWidth => 75.0 * _scale;
  static double get _shopTitleHeight => 42.0 * _scale;
  static const _closeBtnSize = 38.0;
  static const _closeBtnRightMargin = 16.0; // не масштабируется — кнопка закрыть фиксирована
  static double get _elementsTop => (110.0 + _topPadding) * _scale;
  static double get _elementGap => -28.0 * _scale;
  static double get _bannerGap => -120.0 * _scale;
  static double get _bannerWidth => 311.0 * _scale;
  static double get _bannerHeight => 160.0 * _scale;

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
        child: Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: Color(0x4D000000)),
            Positioned(
              top: _shopTitleTop,
              left: 0,
              right: 0,
              child: Center(
                child: SizedBox(
                  width: _shopTitleWidth,
                  height: _shopTitleHeight,
                  child: Image.asset(
                    'assets/images/shop/shop_logo.png',
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => const Text(
                      'SHOP',
                      style: TextStyle(
                        color: Colors.amber,
                        fontSize: 20 * _scale,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: _shopTitleTop,
              right: _closeBtnRightMargin,
              child: PressableButton(
                onTap: () {
                  SettingsService.hapticLightImpact();
                  Navigator.of(context).pop();
                },
                child: SizedBox(
                  width: _closeBtnSize,
                  height: _closeBtnSize,
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
              top: _elementsTop,
              left: 0,
              right: 0,
              bottom: 0,
              child: SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 70),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ...List.generate(
                        _coinOffers.length,
                        (i) => Transform.translate(
                          offset: Offset(0, i > 0 ? _elementGap * i : 0),
                          child: ShopElementCard(
                            coins: _coinOffers[i].$2,
                            contentTopOffset: i == 4 ? 3 : 0,
                            showOnlyForYouBanner: i == 4,
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
                        ),
                      ),
                      Transform.translate(
                        offset: Offset(0, _bannerGap),
                        child: SizedBox(
                          width: _bannerWidth,
                          height: _bannerHeight,
                          child: TapBanner(
                            bannerAsset: 'assets/images/shop/banner_miner_pass.png',
                            width: _bannerWidth,
                            height: _bannerHeight,
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
                  padding: EdgeInsets.only(bottom: 16 * _scale),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Privacy policy',
                        style: _shopFooterLinkStyle(),
                      ),
                      SizedBox(width: 16 * _scale),
                      Text(
                        'Terms of Use',
                        style: _shopFooterLinkStyle(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static TextStyle _shopFooterLinkStyle() {
    return TextStyle(
      fontFamily: 'Gotham',
      fontWeight: FontWeight.w900,
      fontSize: 18 * _scale,
      height: 1.4,
      letterSpacing: -0.36 * _scale,
      decoration: TextDecoration.underline,
      decorationColor: Colors.white,
      color: Colors.white,
    );
  }
}
