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
    this.scale = 0.917,
    this.onBuyTap,
  });

  final int coins;
  final String price;
  final double contentTopOffset;
  final bool showOnlyForYouBanner;
  final double scale;
  final VoidCallback? onBuyTap;

  double get _s => scale;

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
        width: 261 * _s,
        height: 126 * _s,
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
              top: (31 + contentTopOffset) * _s,
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
                      Transform.translate(
                        offset: const Offset(0, 0),
                        child: SizedBox(
                          width: 28 * _s,
                          height: 28 * _s,
                          child: Image.asset(
                            'assets/images/main_screen/coin_icon.png',
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) => Icon(
                              Icons.monetization_on,
                              size: 28 * _s,
                              color: _amountColor,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 8 * _s),
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
              top: 18 * _s,
              left: (261 * _s - 117 * _s) / 2,
              child: Image.asset(
                'assets/images/shop/banner_only_for_you.png',
                width: 117 * _s,
                height: 22 * _s,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => SizedBox(
                  width: 117 * _s,
                  height: 22 * _s,
                    child: Center(
                      child: Text(
                        'ONLY FOR YOU',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                        color: Colors.amber,
                        fontSize: 10 * _s,
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

  TextStyle _amountTextStyle({Color? color, Paint? foreground}) {
    return GoogleFonts.montserrat(
      fontWeight: FontWeight.w900,
      fontSize: 23.24 * _s,
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
            padding: EdgeInsets.symmetric(horizontal: 8 * _s, vertical: 4 * _s),
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
            width: 99 * _s,
            height: 34 * _s,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) =>
                Container(
                  width: 99 * _s,
                  height: 34 * _s,
                  color: Colors.brown.shade800,
                ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 10 * _s, vertical: 4 * _s),
            child: Stack(
              children: [
                Text(
                  price,
                    style: GoogleFonts.montserrat(
                    fontWeight: FontWeight.w900,
                    fontSize: 19.11 * _s,
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
                    fontSize: 19.11 * _s,
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
