import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gold_mine_trolls/assets/common_assets.dart';
import 'package:gold_mine_trolls/services/balance_service.dart';
import 'package:gold_mine_trolls/services/daily_bonus_service.dart';
import 'package:gold_mine_trolls/widgets/pressable_button.dart';
import 'home_screen.dart';

/// Welcome bonus screen — GET FREE GOLD -> Tutorial
class WelcomeBonusScreen extends StatefulWidget {
  const WelcomeBonusScreen({super.key});

  @override
  State<WelcomeBonusScreen> createState() => _WelcomeBonusScreenState();
}

class _WelcomeBonusScreenState extends State<WelcomeBonusScreen> {
  static const _buttonWidth = 238.0;
  static const _buttonHeight = 82.0;
  static const _buttonBottomOffset = 51.0;

  static const _trollWidth = 546.0;
  static const _trollHeight = 449.0;
  static const _trollOffsetX = 100.0;
  int _bonusAmount = 10000;

  @override
  void initState() {
    super.initState();
    _loadBonusAmount();
  }

  Future<void> _loadBonusAmount() async {
    final amount = await DailyBonusService.getTodayBonusAmount();
    if (!mounted) return;
    setState(() => _bonusAmount = amount);
  }

  double _trollScale(double physicalHeight) {
    if (physicalHeight <= 0 || physicalHeight <= 1000) return 1.0;
    return 1.5;
  }

  String _formatAmount(int value) {
    final s = value.toString();
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write(' ');
      b.write(s[i]);
    }
    return b.toString();
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final physicalHeight = mq.devicePixelRatio * mq.size.height;
    final screenHeight = physicalHeight > 0 ? physicalHeight : 812.0;
    final trollScale = _trollScale(screenHeight);
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.none,
        children: [
          _buildBackground(),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              height: 145,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0x00702F18),
                    const Color(0xFF702F18),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 108,
            left: 0,
            right: 0,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 290,
                    height: 82,
                    child: Image.asset(
                      'assets/images/welcome_bonus/welcome_text.png',
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => Text(
                        'Welcome',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              color: Colors.amber,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ),
                  ),
                  Text(
                    'We give you a welcome bonus!',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.gothicA1(
                      color: const Color(0xFFFFFFFF),
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      height: 1.6,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildBonusBox(_formatAmount(_bonusAmount)),
                  const SizedBox(height: 8),
                  Transform.translate(
                    offset: const Offset(-_trollOffsetX, 0),
                    child: Transform.scale(
                      scale: trollScale,
                      child: SizedBox(
                        width: _trollWidth,
                        height: _trollHeight,
                        child: Image.asset(
                          'assets/images/welcome_bonus/troll.png',
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) => Container(
                            color: Colors.amber.withValues(alpha: 0.3),
                            child: const Icon(Icons.face, size: 64),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: _buttonBottomOffset,
            child: Center(
              child: _buildGetGoldButton(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBonusBox(String amountText) {
    return Container(
      width: 161,
      height: 47,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFEA4C), width: 2),
        boxShadow: [
          BoxShadow(
            color: const Color(0x40FFEA4C),
            blurRadius: 3,
            spreadRadius: 0,
            blurStyle: BlurStyle.outer,
          ),
          BoxShadow(
            color: const Color(0x40000000),
            blurRadius: 4,
            offset: const Offset(0, 4),
            blurStyle: BlurStyle.inner,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 32,
            height: 32,
            child: Image.asset(
              'assets/images/welcome_bonus/coin_icon.png',
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => const Icon(
                Icons.monetization_on,
                color: Color(0xFFFFEA4C),
                size: 32,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            amountText,
            style: GoogleFonts.gothicA1(
              color: const Color(0xFFFFFFFF),
              fontSize: 24,
              fontWeight: FontWeight.w900,
              height: 1.0,
              letterSpacing: -0.48,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackground() {
    return Positioned.fill(
      child: Image.asset(
        CommonAssets.background,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF1A1510),
                Color(0xFF2D2418),
                Color(0xFF1A1510),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGetGoldButton(BuildContext context) {
    return PressableButton(
      onTap: () async {
        HapticFeedback.lightImpact();
        final amount = await DailyBonusService.claimTodayBonus();
        if (amount != null) {
          await BalanceService.addBalance(amount);
        }
        if (!context.mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      },
      child: SizedBox(
        width: _buttonWidth,
        height: _buttonHeight,
        child: Image.asset(
          'assets/images/welcome_bonus/btn_get_gold.png',
          fit: BoxFit.fill,
          errorBuilder: (context, error, stackTrace) => Container(
            width: _buttonWidth,
            height: _buttonHeight,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFFFB347),
              borderRadius: BorderRadius.circular(_buttonHeight / 2),
            ),
            child: const Text(
              'GET FREE GOLD',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
