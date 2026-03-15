import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
              style: GoogleFonts.montserrat(color: Colors.white70),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Buy',
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
      body: Stack(
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
            top: _titleTop,
            left: 0,
            right: 0,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Center(
                  child: SizedBox(
                    width: _titleWidth,
                    height: _titleHeight,
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
              ],
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
                child: SizedBox(
                  width: _gridBlockMaxWidth,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.center,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildGridRow(0, 1),
                        const SizedBox(height: _gap),
                        _buildGridRow(2, 3),
                        const SizedBox(height: _gap),
                        _buildGridRow(4, 5),
                      ],
                    ),
                    Positioned(
                      left: _bagBgWidth + _gap / 2 - _arrowWidth / 2,
                      top: _bagBgHeight / 2 - _arrowHeight / 2 + 5,
                      child: _buildArrowRight(),
                    ),
                    Positioned(
                      left: _bagBgWidth + _gap + _bagBgWidth / 2 - _arrowWidth / 2,
                      top: _bagBgHeight + _gap / 2 - _arrowHeight / 2,
                      child: Transform.rotate(
                        angle: math.pi / 2,
                        child: _buildArrowRight(),
                      ),
                    ),
                    Positioned(
                      left: _bagBgWidth + _gap / 2 - _arrowWidth / 2,
                      top: _bagBgHeight + _gap + _bagBgHeight / 2 - _arrowHeight / 2 + 5,
                      child: Transform.rotate(
                        angle: math.pi,
                        child: _buildArrowRight(),
                      ),
                    ),
                    Positioned(
                      left: _bagBgWidth / 2 - _arrowWidth / 2,
                      top: 2 * (_bagBgHeight + _gap) + _gap / 2 - _arrowHeight / 2 - 10,
                      child: Transform.rotate(
                        angle: math.pi / 2,
                        child: _buildArrowRight(),
                      ),
                    ),
                    Positioned(
                      left: _bagBgWidth + _gap / 2 - _arrowWidth / 2,
                      top: 2 * (_bagBgHeight + _gap) + _bagBgHeight / 2 - _arrowHeight / 2 + 5,
                      child: _buildArrowRight(),
                    ),
                  ],
                ),
              ),
            ),
          ),
          ),
        ),
        ],
      ),
    );
  }

  Widget _buildGridRow(int leftIndex, int rightIndex) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildBagTile(leftIndex),
        const SizedBox(width: _gap),
        _buildBagTile(rightIndex),
      ],
    );
  }

  Widget _buildArrowRight() {
    return SizedBox(
      width: _arrowWidth,
      height: _arrowHeight,
      child: Image.asset(
        'assets/images/road_of_luck/arrow.png',
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => Container(
          color: Colors.amber.withValues(alpha: 0.3),
          child: Icon(Icons.arrow_forward, size: _arrowHeight),
        ),
      ),
    );
  }

  Widget _buildBagTile(int index) {
    final amount = _amounts[index];
    final price = _prices[index];
    final isActive = _isActiveStep(index);
    final glowColor = isActive ? _glowOrange : _glowGray;
    final cardContent = _buildBagBg(amount, price, isActive);
    final content = AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: _bagBgWidth,
      height: _bagBgHeight,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: glowColor.withValues(alpha: isActive ? 0.8 : 0.28),
            blurRadius: isActive ? 22 : 12,
            spreadRadius: isActive ? 4 : 1,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
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

  Widget _buildBagBg(int amount, String price, bool isActive) {
    final amountText = _formatCoins(amount);
    return SizedBox(
      width: _bagBgWidth,
      height: _bagBgHeight,
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
            top: 32, // иконка и номинал выше на 3 px
            left: 0,
            right: 0,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: _coinSize,
                  height: _coinSize,
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
                const SizedBox(width: 6),
                _buildAmountText(amountText, isActive),
              ],
            ),
          ),
          Center(
            child: Transform.translate(
              offset: const Offset(0, 15), // +3 px вниз
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
            bottom: 20,
            child: Center(
              child: _buildPriceSection(price, isActive),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceSection(String price, bool isActive) {
    final textColor = isActive ? _activeTextColor : _inactiveTextColor;
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        Image.asset(
          'assets/images/road_of_luck/price_bg.png',
          width: _priceBgWidth,
          height: _priceBgHeight,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => Container(
            width: _priceBgWidth,
            height: _priceBgHeight,
            color: Colors.brown.shade800,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: Transform.translate(
            offset: const Offset(0, -2),
            child: Stack(
            children: [
              Text(
                price,
                style: GoogleFonts.montserrat(
                  fontWeight: FontWeight.w900,
                  fontSize: 19.11,
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
                style: GoogleFonts.montserrat(
                  fontWeight: FontWeight.w900,
                  fontSize: 19.11,
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
        ),
      ],
    );
  }

  Widget _buildAmountText(String text, bool isActive) {
    final textColor = isActive ? _amountColor : _inactiveTextColor;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Stack(
        children: [
          Text(
            text,
            style: GoogleFonts.montserrat(
              fontWeight: FontWeight.w900,
              fontSize: _amountFontSize,
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
              fontSize: _amountFontSize,
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
