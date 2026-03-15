import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gold_mine_trolls/widgets/pressable_button.dart';

/// Single shop offer card: background + coin icon + amount + price
class ShopElementCard extends StatelessWidget {
  const ShopElementCard({
    super.key,
    required this.coins,
    this.price = '\$0.00',
    this.contentTopOffset = 0.0,
    this.showOnlyForYouBanner = false,
    this.onBuyTap,
  });

  final int coins;
  final String price;
  final double contentTopOffset;
  final bool showOnlyForYouBanner;
  final VoidCallback? onBuyTap;

  static const _scale = 0.917; // 0.873 * 1.05 — увеличено на 5% вместе с shop_screen
  static double get _elementWidth => 261 * _scale;
  static double get _onlyForYouBannerWidth => 117 * _scale;
  static double get _onlyForYouBannerHeight => 22 * _scale;
  static double get _elementHeight => 126 * _scale;
  static double get _coinSize => 28 * _scale;
  static double get _priceWidth => 99 * _scale;
  static double get _priceHeight => 34 * _scale;

  static const _amountColor = Color(0xFFFCDE66);
  static const _priceColor = Color(0xFFFFFFFF);
  static const _borderColor = Color(0x40000000);

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
    final amountText = _formatCoins(coins);
    return PressableButton(
      onTap: onBuyTap,
      child: SizedBox(
        width: _elementWidth,
        height: _elementHeight,
        child: Stack(
          fit: StackFit.expand,
          clipBehavior: Clip.none,
          children: [
            Image.asset(
              'assets/images/shop/shop_element.png',
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => Container(
                color: Colors.amber.withValues(alpha: 0.2),
                child: const Icon(Icons.shopping_bag, size: 48),
              ),
            ),
            Positioned(
              top: 34 + contentTopOffset, // 29+5 px вниз для иконки и количества
              left: 0,
              right: 0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
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
                      SizedBox(width: 8 * _scale),
                      _buildAmountText(amountText),
                    ],
                  ),
                  Transform.translate(
                    offset: const Offset(0, -6),
                    child: _buildPriceSection(),
                  ),
                ],
              ),
            ),
          if (showOnlyForYouBanner)
            Positioned(
              top: 18 * _scale,
              left: (_elementWidth - _onlyForYouBannerWidth) / 2,
              child: Image.asset(
                'assets/images/shop/banner_only_for_you.png',
                width: _onlyForYouBannerWidth,
                height: _onlyForYouBannerHeight,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => SizedBox(
                  width: _onlyForYouBannerWidth,
                  height: _onlyForYouBannerHeight,
                  child: const Center(
                    child: Text(
                      'ONLY FOR YOU',
                      style: TextStyle(
                        color: Colors.amber,
                        fontSize: 10 * _scale,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
    );
  }

  static TextStyle _amountTextStyle({Color? color, Paint? foreground}) {
    return GoogleFonts.montserrat(
      fontWeight: FontWeight.w900,
      fontSize: 23.24 * _scale,
      height: 1.6,
      letterSpacing: -0.02,
      color: foreground != null ? null : color,
      foreground: foreground,
      shadows: [
        Shadow(
          color: _borderColor,
          offset: const Offset(0, 2.18),
          blurRadius: 0,
        ),
      ],
    );
  }

  Widget _buildAmountText(String text) {
    return Padding(
            padding: EdgeInsets.symmetric(horizontal: 8 * _scale, vertical: 4 * _scale),
      child: Stack(
        children: [
          Text(
            text,
            style: _amountTextStyle(
              foreground: Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1.5
                ..color = _borderColor,
            ),
          ),
          Text(text, style: _amountTextStyle(color: _amountColor)),
        ],
      ),
    );
  }

  Widget _buildPriceSection() {
    return Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Image.asset(
            'assets/images/shop/price_bg.png',
            width: _priceWidth,
            height: _priceHeight,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) =>
                Container(
                  width: _priceWidth,
                  height: _priceHeight,
                  color: Colors.brown.shade800,
                ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 10 * _scale, vertical: 4 * _scale),
            child: Stack(
              children: [
                Text(
                  price,
                    style: GoogleFonts.montserrat(
                    fontWeight: FontWeight.w900,
                    fontSize: 19.11 * _scale,
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
                    fontSize: 19.11 * _scale,
                    height: 1.6,
                    letterSpacing: -0.02,
                    color: _priceColor,
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
}
