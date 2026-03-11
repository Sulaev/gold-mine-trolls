import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gold_mine_trolls/services/balance_service.dart';
import 'package:gold_mine_trolls/widgets/shop_element_card.dart';
import 'package:gold_mine_trolls/widgets/pressable_button.dart';
import 'package:gold_mine_trolls/widgets/tap_banner.dart';

/// Shop modal — appears over the main screen with darkened background
class ShopScreen extends StatelessWidget {
  const ShopScreen({super.key});

  static const _topPadding = 24.0;
  static const _shopTitleTop = 47.0 + _topPadding;
  static const _shopTitleWidth = 75.0;
  static const _shopTitleHeight = 42.0;
  static const _closeBtnSize = 38.0;
  static const _closeBtnRightMargin = 16.0;
  static const _elementsTop = 110.0 + _topPadding;
  static const _elementGap = -28.0;
  static const _bannerGap = -120.0;
  static const _bannerWidth = 311.0;
  static const _bannerHeight = 160.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      child: Material(
        color: Colors.transparent,
        child: Stack(
          fit: StackFit.expand,
          children: [
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
                        fontSize: 20,
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
                  HapticFeedback.lightImpact();
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
                padding: EdgeInsets.zero,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ...List.generate(
                        5,
                        (i) => Transform.translate(
                          offset: Offset(0, i > 0 ? _elementGap * i : 0),
                          child: ShopElementCard(
                            coins: [100000, 250000, 500000, 1000000, 3000000][i],
                            contentTopOffset: i == 4 ? 10 : 0,
                            showOnlyForYouBanner: i == 4,
                            onBuyTap: () async {
                              HapticFeedback.lightImpact();
                              await BalanceService.addBalance(
                                [100000, 250000, 500000, 1000000, 3000000][i],
                              );
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
                              // TODO: navigate to Miner's Pass
                            },
                          ),
                        ),
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
}
