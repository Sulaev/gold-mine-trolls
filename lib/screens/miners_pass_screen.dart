import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gold_mine_trolls/assets/common_assets.dart';
import 'package:gold_mine_trolls/services/analytics_service.dart';
import 'package:gold_mine_trolls/legal_links.dart';
import 'package:gold_mine_trolls/widgets/pressable_button.dart';

class MinersPassScreen extends StatefulWidget {
  const MinersPassScreen({super.key, required this.source});

  final String source;

  @override
  State<MinersPassScreen> createState() => _MinersPassScreenState();
}

class _MinersPassScreenState extends State<MinersPassScreen> {
  static const _baseScale = 1.14; // 1.2 * 0.95 — базовая пропорция

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

  static const _buttonTextSize = 16.82;

  TextStyle _buttonTextStyle(double scale, {Color? color, Paint? foreground}) {
    final s = _baseScale * scale;
    final fontSize = _buttonTextSize * s;
    return TextStyle(
      fontFamily: 'Gilroy',
      fontWeight: FontWeight.w800,
      fontSize: fontSize,
      height: 1.6,
      letterSpacing: -0.02 * fontSize,
      color: Colors.white,
      inherit: false,
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

  Widget _buildOfferTitle(String assetPath, double scale) {
    final s = _baseScale * scale;
    return SizedBox(
      width: 264.0 * s,
      height: 54.0 * s,
      child: Image.asset(assetPath, fit: BoxFit.contain),
    );
  }

  Widget _buildBuyButton({
    required String assetPath,
    required double width,
    required String topText,
    required String bottomText,
    required String itemId,
    required double scale,
  }) {
    final s = _baseScale * scale;
    return PressableButton(
      onTap: () => _onPlanTap(itemId),
      child: SizedBox(
        width: width,
        height: 58 * s,
        child: Stack(
          fit: StackFit.expand,
          alignment: Alignment.center,
          children: [
            Image.asset(assetPath, fit: BoxFit.fill),
            Center(
              child: DefaultTextStyle(
                style: TextStyle(fontFamily: 'Gilroy', fontWeight: FontWeight.w800),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _outlinedText(topText, styleBuilder: ({Color? color, Paint? foreground}) => _buttonTextStyle(scale, color: color, foreground: foreground)),
                      Transform.translate(
                        offset: Offset(0, -6 * s),
                        child: _outlinedText(bottomText, styleBuilder: ({Color? color, Paint? foreground}) => _buttonTextStyle(scale, color: color, foreground: foreground)),
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

  TextStyle _footerLinkStyle(double scale) {
    final s = _baseScale * scale;
    return TextStyle(
      fontFamily: 'Gotham',
      fontWeight: FontWeight.w900,
      fontSize: 12 * s,
      height: 1.4,
      letterSpacing: -0.02 * 12 * s,
      decoration: TextDecoration.underline,
      decorationColor: Colors.white,
      decorationStyle: TextDecorationStyle.solid,
      decorationThickness: 2.5,
      color: Colors.white,
    );
  }

  Widget _buildFooterCopy(double scale) {
    final s = _baseScale * scale;
    final baseStyle = TextStyle(
      fontFamily: 'Gothic A1',
      fontWeight: FontWeight.w400,
      fontSize: 10.5 * s,
      height: 1.4,
      color: const Color(0xFFFFFFFF),
    );

    return Text(
      'BECOME A VIP TODAY AND ENJOY THE GAME LIKE NEVER BEFORE! ✨',
      textAlign: TextAlign.center,
      style: baseStyle,
    );
  }

  Widget _buildRestoreRow(double scale) {
    final s = _baseScale * scale;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: () => LegalLinks.openTermsOfUse(),
          child: Text('TERMS OF USE', style: _footerLinkStyle(scale)),
        ),
        SizedBox(width: 16 * s),
        Text('RESTORE', style: _footerLinkStyle(scale)),
        SizedBox(width: 16 * s),
        GestureDetector(
          onTap: () => LegalLinks.openPrivacyPolicy(),
          child: Text('PRIVACY POLICY', style: _footerLinkStyle(scale)),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final scale = min(
            constraints.maxWidth / 390,
            constraints.maxHeight / 844,
          ).clamp(0.82, 1.3);
          final s = _baseScale * scale;
          return Stack(
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
                  padding: EdgeInsets.fromLTRB(24 * s, 44 * s, 24 * s, 120 * s),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 300.0 * s,
                          height: 90.0 * s,
                          child: Image.asset(
                            'assets/images/paywall/title.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                        _buildOfferTitle('assets/images/paywall/ex_title1.png', scale),
                        _buildOfferTitle('assets/images/paywall/ex_title2.png', scale),
                        _buildOfferTitle('assets/images/paywall/ex_title3.png', scale),
                        SizedBox(height: 10 * s),
                        _buildBuyButton(
                          assetPath: 'assets/images/paywall/buy_btn_green.png',
                          width: 200 * s,
                          topText: '1 WEEK \$9.99',
                          bottomText: '+ 50,000 COINS',
                          itemId: 'miners_pass_1_week',
                          scale: scale,
                        ),
                        SizedBox(height: 10 * s),
                        _buildBuyButton(
                          assetPath: 'assets/images/paywall/buy_btn_green.png',
                          width: 200 * s,
                          topText: '1 MONTH \$19.99',
                          bottomText: '+ 100,000 COINS',
                          itemId: 'miners_pass_1_month',
                          scale: scale,
                        ),
                        SizedBox(height: 10 * s),
                        _buildBuyButton(
                          assetPath: 'assets/images/paywall/buy_btn_yelow.png',
                          width: 237 * s,
                          topText: '3 MONTH \$39.99',
                          bottomText: '+ 350,000 COINS',
                          itemId: 'miners_pass_3_month',
                          scale: scale,
                        ),
                        SizedBox(height: 6 * s),
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
                    padding: EdgeInsets.fromLTRB(24 * s, 12 * s, 24 * s, 16 * s),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildFooterCopy(scale),
                        SizedBox(height: 6 * s),
                        _buildRestoreRow(scale),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                top: (40.0 + 16.0) * s,
                left: 16.0 * s,
                child: Material(
                  type: MaterialType.transparency,
                  child: PressableButton(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.of(context).pop();
                    },
                    child: SizedBox(
                      width: 38.0 * s,
                      height: 38.0 * s,
                      child: Image.asset(
                        'assets/images/shop/btn_close.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
