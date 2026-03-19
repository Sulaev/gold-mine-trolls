import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gold_mine_trolls/services/analytics_service.dart';
import 'package:gold_mine_trolls/services/balance_service.dart';
import 'package:gold_mine_trolls/services/settings_service.dart';
import 'package:gold_mine_trolls/services/road_of_luck_service.dart';
import 'package:gold_mine_trolls/widgets/pressable_button.dart';

/// Road of Luck screen — full screen with bg, title, close button
class RoadOfLuckScreen extends StatefulWidget {
  const RoadOfLuckScreen({super.key});

  @override
  State<RoadOfLuckScreen> createState() => _RoadOfLuckScreenState();
}

class _RoadOfLuckScreenState extends State<RoadOfLuckScreen> {
  static const _glowOrange = Color(0xFFFF9F2D);
  static const _glowGray = Color(0xFF8A8A8A);
  static const _activeTextColor = Color(0xFFFFEA4C);
  static const _inactiveTextColor = Color(0xFFB8B8B8);

  static const _topPadding = 24.0;
  static const _titleTop = 47.0 + _topPadding;
  static const _titleWidth = 200.0;
  static const _titleHeight = 43.0;
  static const _closeBtnSize = 38.0;
  static const _elementsTop = 110.0 + _topPadding;
  static const _bagBgWidth = 180.0;
  static const _bagBgHeight = 170.0;
  static const _gap = 12.0;
  static const _gridBlockMaxWidth = 355.0;
  static const _closeBtnRightMargin = 16.0;
  static const _arrowWidth = 55.0;
  static const _arrowHeight = 25.0;
  static const _coinSize = 21.0;
  static const _priceBgWidth = 130.0;
  static const _priceBgHeight = 34.0;
  static const _designWidth = 390.0;
  static const _designHeight = 844.0;
  static const _amountFontSize = 15.0;
  static const _amountColor = Color(0xFFFFFFFF);
  static const _borderColor = Color(0x40000000);

  static const _amounts = [
    30000,
    250000,
    500000,
    1000000,
    1500000,
    3000000,
  ];

  static const _prices = [
    'FREE',
    '\$7.99',
    '\$19.00',
    'FREE',
    'FREE',
    'FREE',
  ];

  int _currentStep = 0;
  bool _loading = true;
  bool _processingPurchase = false;

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    final current = await RoadOfLuckService.getCurrentStep();
    if (!mounted) return;
    setState(() {
      _currentStep = current;
      _loading = false;
    });
  }

  bool _isActiveStep(int index) => !_loading && !_processingPurchase && index == _currentStep;

  double _priceValue(String price) {
    if (price == 'FREE') return 0;
    return double.tryParse(price.replaceAll('\$', '')) ?? 0;
  }

  Future<void> _claimStep(int index) async {
    if (!_isActiveStep(index)) return;
    SettingsService.hapticLightImpact();
    final price = _prices[index];
    final isFree = price == 'FREE';

    if (isFree) {
      await _doClaim(index);
      return;
    }

    // Платный шаг: показываем диалог покупки
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2D2418),
        title: Text(
          'Purchase',
          style: GoogleFonts.montserrat(
            color: Colors.white,
            fontWeight: FontWeight.w900,
          ),
        ),
        content: Text(
          'Buy this reward for $price?',
          style: GoogleFonts.montserrat(
            color: Colors.white70,
            fontSize: 16,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Cancel',
              textAlign: TextAlign.center,
              style: GoogleFonts.montserrat(color: Colors.white70),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Buy',
              textAlign: TextAlign.center,
              style: GoogleFonts.montserrat(
                color: _activeTextColor,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );

    if (!mounted || confirmed != true) return;
    await _doClaim(index);
  }

  /// Забирает награду и переходит на следующий шаг (после покупки — автоматически).
  Future<void> _doClaim(int index) async {
    final itemId = 'road_of_luck_step_${index + 1}';
    final price = _prices[index];
    setState(() => _processingPurchase = true);
    await AnalyticsService.reportPurchaseClick(itemId: itemId, type: 'coin');
    try {
      await BalanceService.addBalance(_amounts[index]);
      final nextStep = await RoadOfLuckService.advanceStep();
      await AnalyticsService.reportPurchaseSuccess(
        itemId: itemId,
        price: _priceValue(price),
        type: 'coin',
      );
      if (!mounted) return;
      setState(() {
        _currentStep = nextStep;
        _processingPurchase = false;
      });
    } catch (_) {
      await AnalyticsService.reportPurchaseError(
        itemId: itemId,
        type: 'coin',
      );
      if (!mounted) return;
      setState(() => _processingPurchase = false);
    }
  }

  static String _formatCoins(int value) {
    final s = value.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(' ');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final scale = math.min(
            constraints.maxWidth / _designWidth,
            constraints.maxHeight / _designHeight,
          ).clamp(0.82, 1.3);
          return Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                'assets/images/road_of_luck/bg.png',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: const Color(0xFF1A1510),
                ),
              ),
              Positioned(
                top: _titleTop * scale,
                left: 0,
                right: 0,
                child: Stack(
              alignment: Alignment.center,
              children: [
                Center(
                  child: SizedBox(
                    width: _titleWidth * scale,
                    height: _titleHeight * scale,
                    child: Image.asset(
                      'assets/images/road_of_luck/title.png',
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => const Text(
                        'ROAD OF LUCK',
                        style: TextStyle(
                          color: Colors.amber,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 0,
                  right: _closeBtnRightMargin * scale,
                  child: PressableButton(
                    onTap: () {
                      SettingsService.hapticLightImpact();
                      Navigator.of(context).pop();
                    },
                    child: SizedBox(
                      width: _closeBtnSize * scale,
                      height: _closeBtnSize * scale,
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
              ],
            ),
          ),
              Positioned(
            top: _elementsTop * scale,
            left: 0,
            right: 0,
            bottom: 0,
            child: SingleChildScrollView(
              padding: EdgeInsets.zero,
              child: Center(
                child: SizedBox(
                  width: _gridBlockMaxWidth * scale,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.center,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildGridRow(0, 1, scale),
                            SizedBox(height: _gap * scale),
                            _buildGridRow(2, 3, scale),
                            SizedBox(height: _gap * scale),
                            _buildGridRow(4, 5, scale),
                          ],
                        ),
                        Positioned(
                          left: _bagBgWidth * scale + _gap * scale / 2 - _arrowWidth * scale / 2,
                          top: _bagBgHeight * scale / 2 - _arrowHeight * scale / 2 + 5 * scale,
                          child: _buildArrowRight(scale),
                        ),
                        Positioned(
                          left: _bagBgWidth * scale + _gap * scale + _bagBgWidth * scale / 2 - _arrowWidth * scale / 2,
                          top: _bagBgHeight * scale + _gap * scale / 2 - _arrowHeight * scale / 2,
                          child: Transform.rotate(
                            angle: math.pi / 2,
                            child: _buildArrowRight(scale),
                          ),
                        ),
                        Positioned(
                          left: _bagBgWidth * scale + _gap * scale / 2 - _arrowWidth * scale / 2,
                          top: _bagBgHeight * scale + _gap * scale + _bagBgHeight * scale / 2 - _arrowHeight * scale / 2 + 5 * scale,
                          child: Transform.rotate(
                            angle: math.pi,
                            child: _buildArrowRight(scale),
                          ),
                        ),
                        Positioned(
                          left: _bagBgWidth * scale / 2 - _arrowWidth * scale / 2,
                          top: 2 * (_bagBgHeight + _gap) * scale + _gap * scale / 2 - _arrowHeight * scale / 2 - 10 * scale,
                          child: Transform.rotate(
                            angle: math.pi / 2,
                            child: _buildArrowRight(scale),
                          ),
                        ),
                        Positioned(
                          left: _bagBgWidth * scale + _gap * scale / 2 - _arrowWidth * scale / 2,
                          top: 2 * (_bagBgHeight + _gap) * scale + _bagBgHeight * scale / 2 - _arrowHeight * scale / 2 + 5 * scale,
                          child: _buildArrowRight(scale),
                        ),
                      ],
                    ),
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

  Widget _buildGridRow(int leftIndex, int rightIndex, double scale) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildBagTile(leftIndex, scale),
        SizedBox(width: _gap * scale),
        _buildBagTile(rightIndex, scale),
      ],
    );
  }

  Widget _buildArrowRight(double scale) {
    return SizedBox(
      width: _arrowWidth * scale,
      height: _arrowHeight * scale,
      child: Image.asset(
        'assets/images/road_of_luck/arrow.png',
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => Container(
          color: Colors.amber.withValues(alpha: 0.3),
          child: Icon(Icons.arrow_forward, size: _arrowHeight * scale),
        ),
      ),
    );
  }

  Widget _buildBagTile(int index, double scale) {
    final amount = _amounts[index];
    final price = _prices[index];
    final isActive = _isActiveStep(index);
    final glowColor = isActive ? _glowOrange : _glowGray;
    final cardContent = _buildBagBg(amount, price, isActive, scale);
    final content = AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: _bagBgWidth * scale,
      height: _bagBgHeight * scale,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28 * scale),
        boxShadow: [
          BoxShadow(
            color: glowColor.withValues(alpha: isActive ? 0.8 : 0.28),
            blurRadius: isActive ? 22 : 12,
            spreadRadius: isActive ? 4 : 1,
          ),
        ],
      ),
        child: ClipRRect(
        borderRadius: BorderRadius.circular(26 * scale),
        child: isActive
            ? cardContent
            : Opacity(
                opacity: 0.72,
                child: ColorFiltered(
                  colorFilter: const ColorFilter.matrix([
                    0.2126, 0.7152, 0.0722, 0, 0,
                    0.2126, 0.7152, 0.0722, 0, 0,
                    0.2126, 0.7152, 0.0722, 0, 0,
                    0, 0, 0, 1, 0,
                  ]),
                  child: cardContent,
                ),
              ),
      ),
    );

    if (!isActive) return content;
    return PressableButton(
      onTap: () => _claimStep(index),
      child: content,
    );
  }

  Widget _buildBagBg(int amount, String price, bool isActive, double scale) {
    final amountText = _formatCoins(amount);
    return SizedBox(
      width: _bagBgWidth * scale,
      height: _bagBgHeight * scale,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/road_of_luck/bag_bg.png',
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => Container(
              color: Colors.amber.withValues(alpha: 0.2),
              child: const Icon(Icons.inventory_2, size: 48),
            ),
          ),
          Positioned(
            top: 32 * scale,
            left: 0,
            right: 0,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Transform.translate(
                  offset: Offset(0, 2),
                  child: SizedBox(
                    width: _coinSize * scale,
                    height: _coinSize * scale,
                    child: Image.asset(
                      'assets/images/main_screen/coin_icon.png',
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => Icon(
                        Icons.monetization_on,
                        size: _coinSize,
                        color: _amountColor,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 6 * scale),
                _buildAmountText(amountText, isActive, scale),
              ],
            ),
          ),
          Center(
            child: Transform.translate(
              offset: Offset(0, 15 * scale),
              child: Transform.scale(
                scale: 0.98, // на 2% меньше
                child: Image.asset(
                  'assets/images/road_of_luck/gold_bag.png',
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => Icon(
                    Icons.money,
                    size: 48,
                    color: Colors.amber.shade700,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 20 * scale,
            child: Center(
              child: _buildPriceSection(price, isActive, scale),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceSection(String price, bool isActive, double scale) {
    final textColor = isActive ? _activeTextColor : _inactiveTextColor;
    final w = _priceBgWidth * scale;
    final h = _priceBgHeight * scale;
    final fontSize = 19.11 * scale;
    return SizedBox(
      width: w,
      height: h,
      child: Stack(
        clipBehavior: Clip.none,
        fit: StackFit.expand,
        alignment: Alignment.center,
        children: [
          Image.asset(
            'assets/images/road_of_luck/price_bg.png',
            width: w,
            height: h,
            fit: BoxFit.fill,
            errorBuilder: (context, error, stackTrace) => Container(
              width: w,
              height: h,
              color: Colors.brown.shade800,
            ),
          ),
          Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                Text(
                  price,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.montserrat(
                    fontWeight: FontWeight.w900,
                    fontSize: fontSize,
                    height: 1.6,
                    letterSpacing: -0.02,
                    foreground: Paint()
                      ..style = PaintingStyle.stroke
                      ..strokeWidth = 1.2
                      ..color = _borderColor,
                    shadows: [
                      Shadow(
                        color: _borderColor,
                        offset: const Offset(0, 1.79),
                        blurRadius: 0,
                      ),
                    ],
                  ),
                ),
                Text(
                  price,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.montserrat(
                    fontWeight: FontWeight.w900,
                    fontSize: fontSize,
                    height: 1.6,
                    letterSpacing: -0.02,
                    color: textColor,
                    shadows: [
                      Shadow(
                        color: _borderColor,
                        offset: const Offset(0, 1.79),
                        blurRadius: 0,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmountText(String text, bool isActive, double scale) {
    final textColor = isActive ? _amountColor : _inactiveTextColor;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4 * scale, vertical: 2 * scale),
      child: Stack(
        children: [
          Text(
            text,
            style: GoogleFonts.montserrat(
              fontWeight: FontWeight.w900,
              fontSize: _amountFontSize * scale,
              height: 1.6,
              letterSpacing: -0.02,
              foreground: Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1.2
                ..color = _borderColor,
              shadows: [
                Shadow(
                  color: _borderColor,
                  offset: const Offset(0, 1.79),
                  blurRadius: 0,
                ),
              ],
            ),
          ),
          Text(
            text,
            style: GoogleFonts.montserrat(
              fontWeight: FontWeight.w900,
              fontSize: _amountFontSize * scale,
              height: 1.6,
              letterSpacing: -0.02,
              color: textColor,
              shadows: [
                Shadow(
                  color: _borderColor,
                  offset: const Offset(0, 1.79),
                  blurRadius: 0,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
