import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gold_mine_trolls/assets/common_assets.dart';
import 'package:gold_mine_trolls/screens/card_mine_21_screen.dart';
import 'package:gold_mine_trolls/screens/cautious_miner_screen.dart';
import 'package:gold_mine_trolls/screens/chief_trolls_wheel_screen.dart';
import 'package:gold_mine_trolls/screens/golden_avalanche_screen.dart';
import 'package:gold_mine_trolls/screens/gold_vein_screen.dart';
import 'package:gold_mine_trolls/screens/mine_depth_tower_screen.dart';
import 'package:gold_mine_trolls/screens/miners_pass_screen.dart';
import 'package:gold_mine_trolls/screens/miners_wheel_of_fortune_screen.dart';
import 'package:gold_mine_trolls/screens/road_of_luck_screen.dart';
import 'package:gold_mine_trolls/screens/settings_screen.dart';
import 'package:gold_mine_trolls/screens/shop_screen.dart';
import 'package:gold_mine_trolls/screens/treasure_trail_ladder_screen.dart';
import 'package:gold_mine_trolls/services/analytics_service.dart';
import 'package:gold_mine_trolls/services/balance_service.dart';
import 'package:gold_mine_trolls/widgets/pressable_button.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Animated balance display - smoothly animates from old to new value.
class _AnimatedBalanceText extends StatefulWidget {
  const _AnimatedBalanceText({
    required this.targetValue,
    required this.formatBalance,
    required this.buildBalanceText,
  });

  final int targetValue;
  final String Function(int) formatBalance;
  final Widget Function(String) buildBalanceText;

  @override
  State<_AnimatedBalanceText> createState() => _AnimatedBalanceTextState();
}

class _AnimatedBalanceTextState extends State<_AnimatedBalanceText>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  int _displayValue = 0;
  int _fromValue = 0;
  int _toValue = 0;

  @override
  void initState() {
    super.initState();
    _displayValue = widget.targetValue;
    _fromValue = widget.targetValue;
    _toValue = widget.targetValue;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    _animation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    )..addListener(_onAnimTick);
  }

  void _onAnimTick() {
    if (!mounted) return;
    final t = _animation.value;
    setState(() => _displayValue = (_fromValue + (t * (_toValue - _fromValue)).round()).clamp(0, 0x7FFFFFFF));
  }

  @override
  void didUpdateWidget(_AnimatedBalanceText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.targetValue != oldWidget.targetValue) {
      _fromValue = _displayValue;
      _toValue = widget.targetValue;
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _animation.removeListener(_onAnimTick);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.buildBalanceText(widget.formatBalance(_displayValue));
  }
}

/// Main screen placeholder - will be replaced with full design
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  static const _topIconsTop = 35.0;
  static const _iconGap = 17.0;
  static const _shopWidth = 115.5;
  static const _shopHeight = 109.5;
  static const _roadOfLuckWidth = 82.0;
  static const _roadOfLuckHeight = 123.0;
  static const _minersPassWidth = 134.0;
  static const _minersPassHeight = 70.0;
  static const _logoTopGap = 16.0;
  static const _logoWidth = 214.0;
  static const _logoHeight = 79.0;
  static const _settingsIconWidth = 36.0;
  static const _settingsIconHeight = 38.0;
  static const _settingsRightMargin = 42.0;
  static const _balanceTopGap = 12.0;
  static const _balanceBgWidth = 210.0;
  static const _balanceBgHeight = 74.0;
  static const _coinSize = 21.0;
  static const _addBtnWidth = 48.0;
  static const _addBtnHeight = 48.0;
  static const _addBtnRaise = 6.0;
  static const _gamesHorizontalMargin = 42.0;
  static const _gameButtonSize = 140.0;
  static const _gameButtonGap = 12.0;
  static const _gameShadowColor = Color(0x40FFFFFF);
  static const _tutorialOverlayColor = Color(0xB36D2E11);
  static const _tutorialCardScaleMin = 0.96;
  static const _tutorialCardScaleMax = 1.04;
  static const _tutorialBubbleWidth = 209.0;
  static const _tutorialBubbleHeight = 80.0;
  static const _tutorialTextSize = 24.0;
  static const _tutorialTrollSize = 472.0;
  static const _tutorialTrollBottom = -80.0;
  static const _tutorialTrollShiftRightFactor = 0.35;
  static const _tutorialPrefsStepOneDone = 'tutorial_step_1_done';

  static const _gameAssets = [
    ('assets/images/gold_vein/card.png', 'Gold Vein'),
    ('assets/images/miners_wheel_of_fortune/card.png', "Miner's Wheel"),
    ('assets/images/mine_depth_tower/card.png', 'Mine Depth Tower'),
    ('assets/images/card_mine_21/card.png', 'Card Mine 21'),
    ('assets/images/golden_avalanche/card.png', 'Golden Avalanche'),
    ('assets/images/treasure_trail_ladder/card.png', 'Treasure Trail'),
    ('assets/images/chief_trolls_wheel/card.png', "Chief Troll's Wheel"),
    ('assets/images/cautious_miner/card.png', 'Cautious Miner'),
  ];

  bool _showTutorialStepOne = true;
  bool _tutorialStateLoaded = false;
  late final AnimationController _tutorialPulseController;

  @override
  void initState() {
    super.initState();
    _tutorialPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    )..repeat(reverse: true);
    _loadTutorialState();
  }

  @override
  void dispose() {
    _tutorialPulseController.dispose();
    super.dispose();
  }

  Future<void> _loadTutorialState() async {
    final prefs = await SharedPreferences.getInstance();
    final stepOneDone = prefs.getBool(_tutorialPrefsStepOneDone) ?? false;
    if (!mounted) return;
    setState(() {
      _showTutorialStepOne = !stepOneDone;
      _tutorialStateLoaded = true;
    });
  }

  Future<void> _completeTutorialStepOne() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_tutorialPrefsStepOneDone, true);
    if (!mounted) return;
    setState(() => _showTutorialStepOne = false);
  }

  double _gamesTopOffset() {
    return _topIconsTop +
        _roadOfLuckHeight +
        _logoTopGap +
        _logoHeight +
        _balanceTopGap +
        _balanceBgHeight +
        _addBtnHeight / 2;
  }

  double _firstGameLeft(double screenWidth) {
    final contentWidth = screenWidth - _gamesHorizontalMargin * 2;
    final gap = (contentWidth - _gameButtonSize * 2).clamp(8.0, 24.0);
    final rowWidth = _gameButtonSize * 2 + gap;
    return (screenWidth - rowWidth) / 2;
  }

  void _openShop(BuildContext context) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close shop',
      barrierColor: const Color(0x80000000),
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, animation, secondaryAnimation) =>
          const ShopScreen(source: 'home'),
    );
  }

  void _openSettings(BuildContext context) {
    AnalyticsService.reportSettingsOpen();
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close settings',
      barrierColor: const Color(0x80000000),
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, animation, secondaryAnimation) =>
          const SettingsScreen(),
    );
  }

  List<Widget> _buildTopIconsRow(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final roadCenterX = screenWidth / 2;
    final roadLeft = roadCenterX - _roadOfLuckWidth / 2;
    final shopLeft = roadLeft - _iconGap - _shopWidth;
    final minersLeft = roadLeft + _roadOfLuckWidth + _iconGap;

    final centerY = _topIconsTop + _roadOfLuckHeight / 2;
    final shopTop = centerY - _shopHeight / 2;
    final roadTop = centerY - _roadOfLuckHeight / 2;
    final minersTop = centerY - _minersPassHeight / 2;

    return [
      Positioned(
        top: shopTop,
        left: shopLeft,
        child: PressableButton(
          onTap: () => _openShop(context),
          child: _buildTopIcon(
            'assets/images/main_screen/icon_shop.png',
            _shopWidth,
            _shopHeight,
          ),
        ),
      ),
      Positioned(
        top: roadTop,
        left: roadLeft,
        child: PressableButton(
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => const RoadOfLuckScreen()),
            );
          },
          child: _buildTopIcon(
            'assets/images/main_screen/icon_road_of_luck.png',
            _roadOfLuckWidth,
            _roadOfLuckHeight,
          ),
        ),
      ),
      Positioned(
        top: minersTop,
        left: minersLeft,
        child: PressableButton(
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const MinersPassScreen(source: 'vip'),
              ),
            );
          },
          child: _buildTopIcon(
            'assets/images/main_screen/icon_miners_pass.png',
            _minersPassWidth,
            _minersPassHeight,
          ),
        ),
      ),
    ];
  }

  Widget _buildBalanceText(String value) {
    const strokeColor = Color(0x40000000);
    const fillColor = Color(0xFFFFFFFF);
    final baseStyle = GoogleFonts.montserrat(
      color: fillColor,
      fontSize: 18.58,
      fontWeight: FontWeight.w900,
      height: 1.6,
      letterSpacing: -0.02 * 18.58,
    );
    return Stack(
      children: [
        Text(
          value,
          textAlign: TextAlign.center,
          style: baseStyle.copyWith(
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 0.87
              ..color = strokeColor,
          ),
        ),
        Text(
          value,
          textAlign: TextAlign.center,
          style: baseStyle.copyWith(
            shadows: [
              Shadow(
                color: strokeColor,
                offset: const Offset(0, 1.74),
                blurRadius: 0,
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatBalance(int value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    }
    return value.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]} ',
    );
  }

  Widget _buildBalance() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: _balanceBgWidth,
          height: _balanceBgHeight,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  'assets/images/main_screen/balance_bg.png',
                  fit: BoxFit.fill,
                  errorBuilder: (context, error, stackTrace) =>
                      Container(color: const Color(0xFF4A3528)),
                ),
                Align(
                  alignment: const Alignment(0, 0.3),
                  child: Transform.translate(
                    offset: const Offset(0, -8),
                    child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: _coinSize,
                        height: _coinSize,
                        child: Image.asset(
                          'assets/images/main_screen/coin_icon.png',
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(
                                Icons.monetization_on,
                                color: Color(0xFFFFEA4C),
                                size: 21,
                              ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 80,
                        height: 30,
                        child: ValueListenableBuilder<int>(
                          valueListenable: BalanceService.balanceNotifier,
                          builder: (context, value, _) {
                            return Center(
                              child: _AnimatedBalanceText(
                                targetValue: value,
                                formatBalance: _formatBalance,
                                buildBalanceText: _buildBalanceText,
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          top: _balanceBgHeight - _addBtnHeight / 2 - _addBtnRaise,
          left: (_balanceBgWidth - _addBtnWidth) / 2,
          child: SizedBox(
            width: _addBtnWidth,
            height: _addBtnHeight,
            child: Image.asset(
              'assets/images/main_screen/add_btn.png',
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => Container(
                color: Colors.amber.withValues(alpha: 0.3),
                child: const Icon(Icons.add, color: Colors.white),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLogo(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Center(
          child: SizedBox(
            width: _logoWidth,
            height: _logoHeight,
            child: Image.asset(
              'assets/images/main_screen/logo.png',
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => Container(
                color: Colors.amber.withValues(alpha: 0.3),
                child: Icon(Icons.image_not_supported, size: _logoWidth * 0.3),
              ),
            ),
          ),
        ),
        Positioned(
          right: _settingsRightMargin,
          top: 0,
          bottom: 0,
          child: Center(
            child: PressableButton(
              onTap: () {
                HapticFeedback.lightImpact();
                _openSettings(context);
              },
              child: SizedBox(
                width: _settingsIconWidth,
                height: _settingsIconHeight,
                child: Image.asset(
                  'assets/images/main_screen/icon_settings.png',
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: Colors.amber.withValues(alpha: 0.3),
                    child: Icon(Icons.settings, size: _settingsIconWidth * 0.8),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _onGameTap(BuildContext context, int index) async {
    if (_tutorialStateLoaded && _showTutorialStepOne && index != 0) return;
    HapticFeedback.lightImpact();
    if (index == 0) {
      if (_tutorialStateLoaded && _showTutorialStepOne) {
        await _completeTutorialStepOne();
      }
      if (!context.mounted) return;
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const GoldVeinScreen()));
      return;
    }
    if (index == 1) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const MinersWheelOfFortuneScreen()),
      );
      return;
    }
    if (index == 2) {
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const MineDepthTowerScreen()));
      return;
    }
    if (index == 3) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const CardMine21Screen()),
      );
      return;
    }
    if (index == 4) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const GoldenAvalancheScreen()),
      );
      return;
    }
    if (index == 5) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const TreasureTrailLadderScreen()),
      );
      return;
    }
    if (index == 6) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const ChiefTrollsWheelScreen()),
      );
      return;
    }
    if (index == 7) {
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const CautiousMinerScreen()));
    }
  }

  Widget _buildGameButton(
    BuildContext context,
    String imagePath,
    String label,
    int index,
  ) {
    return PressableButton(
      onTap: () => _onGameTap(context, index),
      child: Container(
        width: _gameButtonSize,
        height: _gameButtonSize,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: _gameShadowColor,
              blurRadius: 14.13,
              spreadRadius: 4.68,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.asset(
            imagePath,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Container(
              color: Colors.amber.withValues(alpha: 0.3),
              child: Icon(Icons.casino, size: 48, color: Colors.amber.shade700),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGamesGrid(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final contentWidth = screenWidth - _gamesHorizontalMargin * 2;
    final gap = (contentWidth - _gameButtonSize * 2).clamp(8.0, 24.0);
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 24),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: _gamesHorizontalMargin,
          ),
          child: Column(
            children: [
              for (var i = 0; i < _gameAssets.length; i += 2)
                Padding(
                  padding: EdgeInsets.only(
                    bottom: i + 2 < _gameAssets.length ? _gameButtonGap : 0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildGameButton(
                        context,
                        _gameAssets[i].$1,
                        _gameAssets[i].$2,
                        i,
                      ),
                      SizedBox(width: gap),
                      _buildGameButton(
                        context,
                        _gameAssets[i + 1].$1,
                        _gameAssets[i + 1].$2,
                        i + 1,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopIcon(String path, double width, double height) {
    return SizedBox(
      width: width,
      height: height,
      child: Image.asset(
        path,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => Container(
          color: Colors.amber.withValues(alpha: 0.3),
          child: Icon(Icons.image_not_supported, size: width * 0.5),
        ),
      ),
    );
  }

  Widget _buildTutorialFirstCard(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final cardLeft = _firstGameLeft(screenWidth);
    final cardTop = _gamesTopOffset();
    return Positioned(
      left: cardLeft,
      top: cardTop,
      child: AnimatedBuilder(
        animation: _tutorialPulseController,
        builder: (context, child) {
          final t = Curves.easeInOut.transform(_tutorialPulseController.value);
          final scale =
              _tutorialCardScaleMin +
              (_tutorialCardScaleMax - _tutorialCardScaleMin) * t;
          return Transform.scale(
            scale: scale,
            child: Container(
              width: _gameButtonSize,
              height: _gameButtonSize,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xE0FFF145).withValues(alpha: 0.85),
                    blurRadius: 18 + (8 * t),
                    spreadRadius: 3 + (2 * t),
                  ),
                ],
              ),
              child: PressableButton(
                onTap: () => _onGameTap(context, 0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(_gameAssets[0].$1, fit: BoxFit.cover),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTutorialOverlay(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final bubbleTop = _gamesTopOffset() + _gameButtonSize + 10;
    final bubbleLeft = (screenWidth - _tutorialBubbleWidth) / 2 - 36;
    return Positioned.fill(
      child: Stack(
        children: [
          const Positioned.fill(
            child: AbsorbPointer(
              absorbing: true,
              child: ColoredBox(color: _tutorialOverlayColor),
            ),
          ),
          _buildTutorialFirstCard(context),
          Positioned(
            right: 40 - _tutorialTrollSize * _tutorialTrollShiftRightFactor,
            bottom: _tutorialTrollBottom,
            child: SizedBox(
              width: _tutorialTrollSize,
              height: _tutorialTrollSize,
              child: IgnorePointer(
                child: Image.asset(
                  'assets/images/tutorial/troll_education.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          Positioned(
            left: bubbleLeft,
            top: bubbleTop,
            child: SizedBox(
              width: _tutorialBubbleWidth,
              height: _tutorialBubbleHeight,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Image.asset(
                    'assets/images/tutorial/info_back.png',
                    fit: BoxFit.fill,
                  ),
                  Text(
                    'Tap to play!',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.gothicA1(
                      color: const Color(0xFFFFFFFF),
                      fontSize: _tutorialTextSize,
                      fontWeight: FontWeight.w900,
                      height: 1.6,
                      letterSpacing: -0.02 * _tutorialTextSize,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
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
                Container(color: const Color(0xBF743809)),
              ],
            ),
          ),
          ..._buildTopIconsRow(context),
          Positioned(
            top: _topIconsTop + _roadOfLuckHeight + _logoTopGap,
            left: 0,
            right: 0,
            child: _buildLogo(context),
          ),
          Positioned(
            top:
                _topIconsTop +
                _roadOfLuckHeight +
                _logoTopGap +
                _logoHeight +
                _balanceTopGap,
            left: 0,
            right: 0,
            child: Center(
              child: PressableButton(
                onTap: () {
                  HapticFeedback.lightImpact();
                  _openShop(context);
                },
                child: _buildBalance(),
              ),
            ),
          ),
          Positioned(
            top: _gamesTopOffset(),
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildGamesGrid(context),
          ),
          if (_tutorialStateLoaded && _showTutorialStepOne)
            _buildTutorialOverlay(context),
        ],
      ),
    );
  }
}
