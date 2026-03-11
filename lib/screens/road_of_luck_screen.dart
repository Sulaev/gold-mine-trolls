import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gold_mine_trolls/widgets/pressable_button.dart';

/// Road of Luck screen — full screen with bg, title, close button
class RoadOfLuckScreen extends StatelessWidget {
  const RoadOfLuckScreen({super.key});

  static const _topPadding = 24.0;
  static const _titleTop = 47.0 + _topPadding;
  static const _titleWidth = 200.0;
  static const _titleHeight = 43.0;
  static const _closeBtnSize = 38.0;
  static const _elementsTop = 110.0 + _topPadding;
  static const _bagBgWidth = 180.0;
  static const _bagBgHeight = 170.0;
  static const _gap = 12.0;
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
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Center(
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
                ),
                Padding(
                  padding: const EdgeInsets.only(right: _closeBtnRightMargin),
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
        ],
      ),
    );
  }

  Widget _buildGridRow(int leftIndex, int rightIndex) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildBagBg(_amounts[leftIndex], _prices[leftIndex]),
        const SizedBox(width: _gap),
        _buildBagBg(_amounts[rightIndex], _prices[rightIndex]),
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

  Widget _buildBagBg(int amount, String price) {
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
            top: 32,
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
                _buildAmountText(amountText),
              ],
            ),
          ),
          Center(
            child: Transform.translate(
              offset: const Offset(0, 10),
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
          Positioned(
            left: 0,
            right: 0,
            bottom: 20,
            child: Center(
              child: _buildPriceSection(price),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceSection(String price) {
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
                  color: _amountColor,
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
    );
  }

  Widget _buildAmountText(String text) {
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
              color: _amountColor,
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
