import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gold_mine_trolls/assets/common_assets.dart';
import 'package:gold_mine_trolls/services/analytics_service.dart';
import 'package:gold_mine_trolls/widgets/pressable_button.dart';

class MinersPassScreen extends StatefulWidget {
  const MinersPassScreen({super.key, required this.source});

  final String source;

  @override
  State<MinersPassScreen> createState() => _MinersPassScreenState();
}

class _MinersPassScreenState extends State<MinersPassScreen> {
  static const _scale = 1.14; // 1.2 * 0.95 — уменьшено на 5%
  static double get _topPadding => 16.0 * _scale;
  static double get _headerTop => (40.0 + 16.0) * _scale;
  static double get _closeBtnSize => 38.0 * _scale;
  static double get _closeBtnLeftMargin => 16.0 * _scale;
  static double get _titleWidth => 300.0 * _scale;
  static double get _titleHeight => 90.0 * _scale;
  static double get _bannerWidth => 264.0 * _scale;
  static double get _bannerHeight => 54.0 * _scale;

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
    await AnalyticsService.reportPurchaseClick(itemId: itemId, type: 'sub');
  }

  static const _buttonTextSize = 16.0;

  TextStyle _buttonTextStyle({Color? color, Paint? foreground}) {
    return TextStyle(
      fontFamily: 'Gilroy',
      fontWeight: FontWeight.w900,
      fontSize: _buttonTextSize * _scale,
      height: 1.35,
      letterSpacing: -0.02 * _buttonTextSize * _scale,
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
          style:           styleBuilder(
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 0.93
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
      child: Image.asset(assetPath, fit: BoxFit.contain),
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
        height: 58 * _scale,
        child: Stack(
          fit: StackFit.expand,
          alignment: Alignment.center,
          children: [
            Image.asset(assetPath, fit: BoxFit.fill),
            Transform.translate(
              offset: const Offset(0, 4),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _outlinedText(topText, styleBuilder: _buttonTextStyle),
                    Transform.translate(
                      offset: const Offset(0, -2),
                      child: _outlinedText(
                        bottomText,
                        styleBuilder: _buttonTextStyle,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static TextStyle _footerLinkStyle() {
    return TextStyle(
      fontFamily: 'Gotham',
      fontWeight: FontWeight.w900,
      fontSize: 14 * _scale,
      height: 1.4,
      letterSpacing: -0.02 * 14 * _scale,
      decoration: TextDecoration.underline,
      decorationColor: Colors.white,
      color: Colors.white,
    );
  }

  Widget _buildFooterCopy() {
    final baseStyle = TextStyle(
      fontFamily: 'Gothic A1',
      fontWeight: FontWeight.w400,
      fontSize: 10.5 * _scale,
      height: 1.4,
      color: const Color(0xFFFFFFFF),
    );

    return Text(
      'BECOME A VIP TODAY AND ENJOY THE GAME LIKE NEVER BEFORE! ✨',
      textAlign: TextAlign.center,
      style: baseStyle,
    );
  }

  Widget _buildRestoreRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('Terms of Use', style: _footerLinkStyle()),
        SizedBox(width: 16 * _scale),
        Text('RESTORE', style: _footerLinkStyle()),
        SizedBox(width: 16 * _scale),
        Text('Privacy policy', style: _footerLinkStyle()),
      ],
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
              padding: EdgeInsets.fromLTRB(24 * _scale, 44 * _scale, 24 * _scale, 120 * _scale),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: _titleWidth,
                      height: _titleHeight,
                      child: Image.asset(
                        'assets/images/paywall/title.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                    _buildOfferTitle('assets/images/paywall/ex_title1.png'),
                    _buildOfferTitle('assets/images/paywall/ex_title2.png'),
                    _buildOfferTitle('assets/images/paywall/ex_title3.png'),
                    SizedBox(height: 10 * _scale),
                    _buildBuyButton(
                      assetPath: 'assets/images/paywall/buy_btn_green.png',
                      width: 200 * _scale,
                      topText: '1 WEEK \$9.99',
                      bottomText: '+ 50,000 COINS',
                      itemId: 'miners_pass_1_week',
                    ),
                    SizedBox(height: 10 * _scale),
                    _buildBuyButton(
                      assetPath: 'assets/images/paywall/buy_btn_green.png',
                      width: 200 * _scale,
                      topText: '1 MONTH \$19.99',
                      bottomText: '+ 100,000 COINS',
                      itemId: 'miners_pass_1_month',
                    ),
                    SizedBox(height: 10 * _scale),
                    _buildBuyButton(
                      assetPath: 'assets/images/paywall/buy_btn_yelow.png',
                      width: 237 * _scale,
                      topText: '3 MONTH \$39.99',
                      bottomText: '+ 350,000 COINS',
                      itemId: 'miners_pass_3_month',
                    ),
                    SizedBox(height: 6 * _scale),
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
                padding: EdgeInsets.fromLTRB(24 * _scale, 12 * _scale, 24 * _scale, 16 * _scale),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildFooterCopy(),
                    SizedBox(height: 6 * _scale),
                    _buildRestoreRow(),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: _headerTop,
            left: _closeBtnLeftMargin,
            child: Material(
              type: MaterialType.transparency,
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
          ),
        ],
      ),
    );
  }
}
