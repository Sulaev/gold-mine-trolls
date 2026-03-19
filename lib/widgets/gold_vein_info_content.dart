import 'package:flutter/material.dart';
import 'package:gold_mine_trolls/screens/info_screen.dart';

/// Gold Vein info content: 4×3 grid of slot icons with multipliers.
class GoldVeinInfoContent extends StatelessWidget {
  const GoldVeinInfoContent({super.key});

  static const _iconWidth = 74.0;
  static const _iconHeight = 52.0;
  static const _colGap = 6.0;
  static const _rowGap = 8.0;
  static const _multiplierTopGap = 2.0;

  static const _symbols = [
    'assets/images/gold_vein/slots/1.1.png',
    'assets/images/gold_vein/slots/1.2.png',
    'assets/images/gold_vein/slots/1.3.png',
    'assets/images/gold_vein/slots/1.4.png',
    'assets/images/gold_vein/slots/1.5.png',
    'assets/images/gold_vein/slots/1.6.png',
    'assets/images/gold_vein/slots/1.7.png',
    'assets/images/gold_vein/slots/1.8.png',
    'assets/images/gold_vein/slots/1.9.png',
    'assets/images/gold_vein/slots/1.10.png',
    'assets/images/gold_vein/slots/1.11.png',
    'assets/images/gold_vein/slots/1.12.png',
  ];

  static const _multipliers = [
    'X10',
    'X1.3',
    'X1.4',
    'X1.6',
    'X1.1',
    'X2.6',
    'X6.5',
    'X3.5',
    'X8.2',
    'X1.8',
    'X4.8',
    'X2.3',
  ];

  static const _iconsTopOffset = 80.0;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Transform.translate(
        offset: const Offset(0, _iconsTopOffset),
        child: Column(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(4, (row) {
          return Padding(
            padding: EdgeInsets.only(bottom: row < 3 ? _rowGap : 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (col) {
                final i = row * 3 + col;
                return Padding(
                  padding: EdgeInsets.only(right: col < 2 ? _colGap : 0),
                  child: SizedBox(
                    width: _iconWidth,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: _iconWidth,
                          height: _iconHeight,
                          child: Image.asset(
                            _symbols[i],
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) =>
                                Icon(
                                  Icons.casino,
                                  size: _iconHeight * 0.6,
                                  color: Colors.amber.shade700,
                                ),
                          ),
                        ),
                        SizedBox(height: _multiplierTopGap),
                        _buildMultiplierText(_multipliers[i]),
                      ],
                    ),
                  ),
                );
              }),
            ),
          );
        }),
        ),
      ),
    );
  }

  Widget _buildMultiplierText(String text) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: InfoScreen.multiplierTextStyle().copyWith(
        shadows: const [
          Shadow(
            color: Color(0x40000000),
            offset: Offset(0, 2),
            blurRadius: 0,
          ),
        ],
      ),
    );
  }
}
