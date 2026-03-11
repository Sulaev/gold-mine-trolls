import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gold_mine_trolls/assets/common_assets.dart';
import 'package:gold_mine_trolls/services/analytics_service.dart';
import 'package:gold_mine_trolls/widgets/pressable_button.dart';

class MinersPassScreen extends StatefulWidget {
  const MinersPassScreen({
    super.key,
    required this.source,
  });

  final String source;

  @override
  State<MinersPassScreen> createState() => _MinersPassScreenState();
}

class _MinersPassScreenState extends State<MinersPassScreen> {
  static const _topPadding = 16.0;
  static const _headerTop = 40.0 + _topPadding;
  static const _closeBtnSize = 38.0;
  static const _closeBtnLeftMargin = 16.0;
  static const _titleWidth = 300.0;
  static const _titleHeight = 90.0;
  static const _bannerWidth = 264.0;
  static const _bannerHeight = 54.0;

  @override
  void initState() {
    super.initState();
    AnalyticsService.reportPaywallView(widget.source);
  }

  @override
  void dispose() {
    AnalyticsService.reportPaywallClose(widget.source);
    super.dispose();
  }

  Future<void> _onPlanTap(String itemId) async {
    HapticFeedback.lightImpact();
    await AnalyticsService.reportPurchaseClick(
      itemId: itemId,
      type: 'sub',
    );
  }

  TextStyle _topTextStyle({Color? color, Paint? foreground}) {
    return const TextStyle(
      fontFamily: 'Gilroy',
      fontWeight: FontWeight.w900,
      fontSize: 13.5,
      height: 1.35,
      letterSpacing: -0.02 * 13.5,
      color: Colors.white,
    ).copyWith(
      color: foreground == null ? color : null,
      foreground: foreground,
    );
  }

  TextStyle _bottomTextStyle({Color? color, Paint? foreground}) {
    return const TextStyle(
      fontFamily: 'Gilroy',
      fontWeight: FontWeight.w900,
      fontSize: 16.5,
      height: 1.35,
      letterSpacing: -0.02 * 16.5,
      color: Colors.white,
    ).copyWith(
      color: foreground == null ? color : null,
      foreground: foreground,
    );
  }

  Widget _outlinedText(
    String text, {
    required TextStyle Function({Color? color, Paint? foreground}) styleBuilder,
  }) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Text(
          text,
          textAlign: TextAlign.center,
          style: styleBuilder(
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = styleBuilder == _topTextStyle ? 0.7 : 0.93
              ..color = const Color(0x4070AC17),
          ),
        ),
        Text(
          text,
          textAlign: TextAlign.center,
          style: styleBuilder(color: const Color(0xFFFFFFFF)),
        ),
      ],
    );
  }

  Widget _buildOfferTitle(String assetPath) {
    return SizedBox(
      width: _bannerWidth,
      height: _bannerHeight,
      child: Image.asset(
        assetPath,
        fit: BoxFit.contain,
      ),
    );
  }

  Widget _buildBuyButton({
    required String assetPath,
    required double width,
    required String topText,
    required String bottomText,
    required String itemId,
  }) {
    return PressableButton(
      onTap: () => _onPlanTap(itemId),
      child: SizedBox(
        width: width,
        height: 58,
        child: Stack(
          fit: StackFit.expand,
          alignment: Alignment.center,
          children: [
            Image.asset(
              assetPath,
              fit: BoxFit.fill,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _outlinedText(topText, styleBuilder: _topTextStyle),
                  Transform.translate(
                    offset: const Offset(0, -2),
                    child: _outlinedText(
                      bottomText,
                      styleBuilder: _bottomTextStyle,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooterCopy() {
    const baseStyle = TextStyle(
      fontFamily: 'Gothic A1',
      fontWeight: FontWeight.w400,
      fontSize: 10.5,
      height: 1.4,
      color: Color(0xFFFFFFFF),
    );
    const underline = TextDecoration.underline;

    return Text.rich(
      const TextSpan(
        style: baseStyle,
        children: [
          TextSpan(
            text:
                'BECOME A VIP TODAY AND ENJOY THE GAME LIKE NEVER BEFORE! ',
          ),
          TextSpan(text: '✨ '),
          TextSpan(
            text: 'Terms of Use',
            style: TextStyle(decoration: underline),
          ),
          TextSpan(text: ' & '),
          TextSpan(
            text: 'Privacy policy',
            style: TextStyle(decoration: underline),
          ),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildRestorePurchases() {
    return Text(
      'RESTORE PURCHASES',
      textAlign: TextAlign.center,
      style: const TextStyle(
        fontFamily: 'Gotham',
        fontWeight: FontWeight.w900,
        fontSize: 14,
        height: 1.4,
        letterSpacing: -0.02 * 14,
        decoration: TextDecoration.underline,
        color: Colors.white,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            CommonAssets.background,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) =>
                Container(color: const Color(0xFF1A1510)),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 36, 20, 12),
              child: Column(
                children: [
                  SizedBox(
                    width: _titleWidth,
                    height: _titleHeight,
                    child: Image.asset(
                      'assets/images/paywall/title.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 2),
                  _buildOfferTitle('assets/images/paywall/ex_title1.png'),
                  const SizedBox(height: 2),
                  _buildOfferTitle('assets/images/paywall/ex_title2.png'),
                  const SizedBox(height: 2),
                  _buildOfferTitle('assets/images/paywall/ex_title3.png'),
                  const SizedBox(height: 6),
                  _buildBuyButton(
                    assetPath: 'assets/images/paywall/buy_btn_green.png',
                    width: 200,
                    topText: '1 MONTH \$9.99',
                    bottomText: '+ 100,000 COINS',
                    itemId: 'miners_pass_1_month',
                  ),
                  const SizedBox(height: 5),
                  _buildBuyButton(
                    assetPath: 'assets/images/paywall/buy_btn_green.png',
                    width: 200,
                    topText: '3 MONTH \$29.99',
                    bottomText: '+ 350,000 COINS',
                    itemId: 'miners_pass_3_month',
                  ),
                  const SizedBox(height: 5),
                  _buildBuyButton(
                    assetPath: 'assets/images/paywall/buy_btn_green.png',
                    width: 200,
                    topText: '6 MONTH \$49.99',
                    bottomText: '+ 650,000 COINS',
                    itemId: 'miners_pass_6_month',
                  ),
                  const SizedBox(height: 6),
                  _buildBuyButton(
                    assetPath: 'assets/images/paywall/buy_btn_yelow.png',
                    width: 237,
                    topText: '12 MONTH \$69.99',
                    bottomText: '+ 1,500,000 COINS',
                    itemId: 'miners_pass_12_month',
                  ),
                  const SizedBox(height: 6),
                  _buildFooterCopy(),
                  const SizedBox(height: 6),
                  _buildRestorePurchases(),
                ],
              ),
            ),
          ),
          Positioned(
            top: _headerTop,
            left: _closeBtnLeftMargin,
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
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
