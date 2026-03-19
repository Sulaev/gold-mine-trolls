import 'dart:async';
import 'dart:math';

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
import 'package:gold_mine_trolls/screens/miners_wheel_of_fortune_screen.dart';
import 'package:gold_mine_trolls/screens/road_of_luck_screen.dart';
import 'package:gold_mine_trolls/screens/settings_screen.dart';
import 'package:gold_mine_trolls/screens/shop_screen.dart';
import 'package:gold_mine_trolls/screens/treasure_trail_ladder_screen.dart';
import 'package:gold_mine_trolls/services/analytics_service.dart';
import 'package:gold_mine_trolls/services/audio_service.dart';
import 'package:gold_mine_trolls/services/balance_service.dart';
import 'package:gold_mine_trolls/services/settings_service.dart';
import 'package:gold_mine_trolls/services/tutorial_service.dart';
import 'package:gold_mine_trolls/widgets/miners_pass_button.dart';
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
    with TickerProviderStateMixin, WidgetsBindingObserver {
  static const _topIconsTop = 35.0;
  static const _iconGap = 8.0;
  static const _topIconWidth = 132.0;
  static const _topIconHeight = 88.0;
  static const _shopWidth = 132.0;
  static const _shopHeight = 88.0;
  static const _roadOfLuckWidth = 82.0;
  static const _roadOfLuckHeight = 122.0;
  static const _minersPassWidth = 132.0;
  static const _minersPassHeight = 88.0;
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
  static const _gamesTopGlowPadding = 14.0;
  static const _gameShadowColor = Color(0x40FFFFFF);
  static const _tutorialOverlayColor = Color(0xB36D2E11);
  static const _tutorialCardScaleMin = 0.96;
  static const _tutorialCardScaleMax = 1.04;
  static const _tutorialBubbleWidth = 209.0;
  static const _tutorialBubbleHeight = 80.0;
  static const _tutorialTextSize = 24.0;
  static const _tutorialTrollSize = 420.0; // 280 * 1.5
  static const _tutorialTrollBottom = 0.0;
  static const _tutorialPrefsStepOneDone = 'tutorial_step_1_done';

  static const _designWidth = 390.0;
  static const _designHeight = 844.0;

  static const _gameAssets = [
    ('assets/images/main_screen/game_banners/gold_vein.png', 'Gold Vein'),
    ('assets/images/main_screen/game_banners/golden_avalanche.png', 'Golden Avalanche'),
    ('assets/images/main_screen/game_banners/mine_depth_tower.png', 'Mine Depth Tower'),
    ('assets/images/main_screen/game_banners/chief_trolls_wheel.png', "Chief Troll's Wheel"),
    ('assets/images/main_screen/game_banners/miners_wheel_of_fortune.png', "Miner's Wheel"),
    ('assets/images/main_screen/game_banners/treasure_trail_ladder.png', 'Treasure Trail'),
    ('assets/images/main_screen/game_banners/card_mine_21.png', 'Card Mine 21'),
    ('assets/images/main_screen/game_banners/cautious_miner.png', 'Cautious Miner'),
  ];

  /// Gold Vein is the tutorial game. Index where it appears in the grid.
  static const _tutorialGameIndex = 0;
  static const _goldenAvalancheIndex = 1;

  bool _showTutorialStepOne = true;
  bool _tutorialStateLoaded = false;
  late final AnimationController _tutorialPulseController;
  final ScrollController _mainScrollController = ScrollController();
  bool _gamesAutoScrollRunning = false;
  int _gamesAutoScrollSession = 0;
  Timer? _gamesIdleRestartTimer;
  Timer? _idleScrollDelayTimer;
  bool _wasCurrentRoute = false;
  static const _idleScrollDelaySec = 5;

  /// Реальная позиция кнопки Gold Vein (для пульса при адаптивной вёрстке).
  final GlobalKey _goldVeinTutorialTargetKey = GlobalKey();
  final GlobalKey _tutorialOverlayStackKey = GlobalKey();
  final GlobalKey _gamesGridKey = GlobalKey();
  Rect? _tutorialGoldVeinRect;
  bool _tutorialScrollListenerAttached = false;
  ({double margin, double size, double gap, double verticalGap})? _lastGamesGridLayout;

  void _scheduleIdleScrollAfterDelay() {
    _idleScrollDelayTimer?.cancel();
    if (_showTutorialStepOne) return; // не планировать анимацию пролёта во время обучения
    _idleScrollDelayTimer = Timer(const Duration(seconds: _idleScrollDelaySec), () {
      _idleScrollDelayTimer = null;
      if (mounted) _tryStartGamesIdleAutoScroll();
    });
  }

  @override
  void initState() {
    super.initState();
    _tutorialPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    )..repeat(reverse: true);
    WidgetsBinding.instance.addObserver(this);
    _loadTutorialState();
    unawaited(AudioService.instance.ensureMinersWheelSpinLoaded());
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    if (_showTutorialStepOne) _scheduleSyncTutorialPulsePosition();
  }

  void _scheduleSyncTutorialPulsePosition() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_showTutorialStepOne) return;
      _syncTutorialPulsePosition();
      // Вторая отрисовка: сетка игр и оверлей могут измериться в разных фазах.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_showTutorialStepOne) return;
        _syncTutorialPulsePosition();
      });
    });
  }

  void _syncTutorialPulsePosition() {
    final targetCtx = _goldVeinTutorialTargetKey.currentContext;
    final overlayCtx = _tutorialOverlayStackKey.currentContext;
    if (targetCtx == null || overlayCtx == null) return;
    final gameBox = targetCtx.findRenderObject() as RenderBox?;
    final overlayBox = overlayCtx.findRenderObject() as RenderBox?;
    if (gameBox == null ||
        overlayBox == null ||
        !gameBox.hasSize ||
        !overlayBox.hasSize) {
      return;
    }
    final topLeft = overlayBox.globalToLocal(
      gameBox.localToGlobal(Offset.zero),
    );
    final w = gameBox.size.width;
    final h = gameBox.size.height;
    final newRect = Rect.fromLTWH(topLeft.dx, topLeft.dy, w, h);
    if (_tutorialGoldVeinRect == null ||
        (_tutorialGoldVeinRect!.left - newRect.left).abs() > 0.5 ||
        (_tutorialGoldVeinRect!.top - newRect.top).abs() > 0.5 ||
        (_tutorialGoldVeinRect!.width - newRect.width).abs() > 0.5 ||
        (_tutorialGoldVeinRect!.height - newRect.height).abs() > 0.5) {
      setState(() => _tutorialGoldVeinRect = newRect);
    }
  }

  void _attachTutorialPositionSync() {
    if (_tutorialScrollListenerAttached) return;
    _tutorialScrollListenerAttached = true;
    _mainScrollController.addListener(_scheduleSyncTutorialPulsePosition);
  }

  void _detachTutorialPositionSync() {
    if (!_tutorialScrollListenerAttached) return;
    _tutorialScrollListenerAttached = false;
    _mainScrollController.removeListener(_scheduleSyncTutorialPulsePosition);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _detachTutorialPositionSync();
    _idleScrollDelayTimer?.cancel();
    _tutorialPulseController.dispose();
    _gamesIdleRestartTimer?.cancel();
    _mainScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadTutorialState() async {
    final tutorialsCompleted = await TutorialService.isTutorialsCompleted();
    final prefs = await SharedPreferences.getInstance();
    final stepOneDone = TutorialService.forceTutorialForTesting
        ? false
        : (prefs.getBool(_tutorialPrefsStepOneDone) ?? false);
    if (!mounted) return;
    final show = !tutorialsCompleted && !stepOneDone;
    setState(() {
      _showTutorialStepOne = show;
      _tutorialStateLoaded = true;
      if (!show) {
        _tutorialGoldVeinRect = null;
        _detachTutorialPositionSync();
      }
    });
    if (show) {
      _attachTutorialPositionSync();
      _scheduleSyncTutorialPulsePosition();
    }
    _scheduleIdleScrollAfterDelay();
  }

  Future<void> _completeTutorialStepOne() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_tutorialPrefsStepOneDone, true);
    if (!mounted) return;
    _detachTutorialPositionSync();
    setState(() {
      _showTutorialStepOne = false;
      _tutorialGoldVeinRect = null;
    });
    _scheduleIdleScrollAfterDelay();
  }

  void _tryStartGamesIdleAutoScroll() {
    if (_gamesAutoScrollRunning || !_tutorialStateLoaded || _showTutorialStepOne) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _gamesAutoScrollRunning || !_mainScrollController.hasClients) {
        return;
      }
      if (_mainScrollController.position.maxScrollExtent <= 0) return;
      _gamesAutoScrollRunning = true;
      final session = ++_gamesAutoScrollSession;
      unawaited(_runGamesIdleAutoScrollLoop(session));
    });
  }

  void _pauseGamesAutoScrollForUserInteraction() {
    _gamesAutoScrollSession++;
    _gamesAutoScrollRunning = false;
    _gamesIdleRestartTimer?.cancel();
    _gamesIdleRestartTimer = Timer(const Duration(seconds: 5), () {
      if (!mounted) return;
      _tryStartGamesIdleAutoScroll();
    });
  }

  /// Open game at touch position when user taps during auto-scroll (one-tap during animation).
  void _openGameAtScrollTouch(BuildContext context, DragStartDetails details) {
    final layout = _lastGamesGridLayout;
    if (layout == null) return;
    final box = _gamesGridKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final local = box.globalToLocal(details.globalPosition);
    final margin = layout.margin;
    final size = layout.size;
    final gap = layout.gap;
    final verticalGap = layout.verticalGap;
    final gridHeight = 4 * size + 3 * verticalGap;
    final gridWidth = 2 * size + gap;
    if (local.dy < 0 || local.dy >= gridHeight) return;
    if (local.dx < margin || local.dx >= margin + gridWidth) return;
    final row = (local.dy / (size + verticalGap)).floor().clamp(0, 3);
    final col = (local.dx - margin) < (size + gap / 2) ? 0 : 1;
    final index = row * 2 + col;
    if (index >= 0 && index < _gameAssets.length) {
      _onGameTap(context, index);
    }
  }

  Future<void> _runGamesIdleAutoScrollLoop(int session) async {
    while (mounted &&
        !_showTutorialStepOne &&
        _gamesAutoScrollRunning &&
        session == _gamesAutoScrollSession &&
        _mainScrollController.hasClients) {
      final max = _mainScrollController.position.maxScrollExtent;
      if (max <= 0) break;
      if (_mainScrollController.position.pixels < max - 0.5) {
        await _mainScrollController.animateTo(
          max,
          duration: const Duration(seconds: 10),
          curve: Curves.easeInOut,
        );
      }
      if (!mounted ||
          !_gamesAutoScrollRunning ||
          session != _gamesAutoScrollSession ||
          !_mainScrollController.hasClients) {
        break;
      }
      await Future<void>.delayed(const Duration(milliseconds: 350));
      if (_mainScrollController.position.pixels > 0.5) {
        await _mainScrollController.animateTo(
          0,
          duration: const Duration(seconds: 10),
          curve: Curves.easeInOut,
        );
      }
      if (!mounted ||
          !_gamesAutoScrollRunning ||
          session != _gamesAutoScrollSession ||
          !_mainScrollController.hasClients) {
        break;
      }
      await Future<void>.delayed(const Duration(milliseconds: 350));
    }
    if (mounted && session == _gamesAutoScrollSession) {
      _gamesAutoScrollRunning = false;
    }
  }

  /// Scaled layout: all sizes use scale from LayoutBuilder.
  ({double gap, double scale}) _topIconsLayout(double availableWidth, double scale) {
    final totalIconWidth = (_shopWidth + _roadOfLuckWidth + _minersPassWidth) * scale;
    final minGap = 4.0 * scale;
    final iconGap = _iconGap * scale;

    if (availableWidth >= totalIconWidth + iconGap * 2) {
      return (gap: iconGap, scale: scale);
    }

    final compactGap =
        ((availableWidth - totalIconWidth) / 2).clamp(minGap, iconGap);
    if (compactGap >= minGap && availableWidth >= totalIconWidth + compactGap * 2) {
      return (gap: compactGap, scale: scale);
    }

    final iconScale =
        ((availableWidth - minGap * 2) / totalIconWidth).clamp(0.7, 1.0);
    return (gap: minGap, scale: scale * iconScale);
  }

  /// Scaled layout: sizes use scale from LayoutBuilder.
  ({double margin, double size, double gap, double verticalGap}) _gamesGridLayout(
    double screenWidth,
    double scale,
  ) {
    final minMargin = 12.0 * scale;
    final minHorizontalGap = 4.0 * scale;
    final minVerticalGap = 4.0 * scale;
    final minSize = 100.0 * scale;

    var margin = _gamesHorizontalMargin * scale;
    var gap = 24.0 * scale;
    var verticalGap = _gameButtonGap * scale;
    final size = _gameButtonSize * scale;

    var contentWidth = screenWidth - margin * 2;
    if (contentWidth >= size * 2 + minHorizontalGap) {
      gap = (contentWidth - size * 2).clamp(minHorizontalGap, 24.0 * scale);
      return (margin: margin, size: size, gap: gap, verticalGap: verticalGap);
    }

    margin = ((screenWidth - (size * 2 + minHorizontalGap)) / 2)
        .clamp(minMargin, _gamesHorizontalMargin * scale);
    contentWidth = screenWidth - margin * 2;
    if (contentWidth >= size * 2 + minHorizontalGap) {
      gap = (contentWidth - size * 2).clamp(minHorizontalGap, 24.0 * scale);
      verticalGap = margin > 30 * scale ? _gameButtonGap * scale : 8.0 * scale;
      return (margin: margin, size: size, gap: gap, verticalGap: verticalGap);
    }

    final reducedSize = ((screenWidth - minMargin * 2 - minHorizontalGap) / 2)
        .clamp(minSize, _gameButtonSize * scale);
    contentWidth = screenWidth - minMargin * 2;
    gap = (contentWidth - reducedSize * 2).clamp(minHorizontalGap, 24.0 * scale);
    verticalGap = minVerticalGap;
    return (
      margin: minMargin,
      size: reducedSize,
      gap: gap,
      verticalGap: verticalGap,
    );
  }

  double _gamesTopOffset(BuildContext context, double scale) {
    final availableWidth = MediaQuery.sizeOf(context).width -
        MediaQuery.paddingOf(context).horizontal;
    final topIcons = _topIconsLayout(availableWidth, scale);
    return _topIconsTop * scale +
        (_roadOfLuckHeight * topIcons.scale) +
        _logoTopGap * scale +
        _logoHeight * scale +
        _balanceTopGap * scale +
        _balanceBgHeight * scale +
        _addBtnHeight / 2 * scale;
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

  Widget _buildTopIconsRowContent(BuildContext context, double maxWidth, double scale) {
    final layout = _topIconsLayout(maxWidth, scale);
    final shopW = _shopWidth * layout.scale;
    final shopH = _shopHeight * layout.scale;
    final roadW = _roadOfLuckWidth * layout.scale;
    final roadH = _roadOfLuckHeight * layout.scale;
    final minersW = _minersPassWidth * layout.scale;
    final minersH = _minersPassHeight * layout.scale;
    final gap = layout.gap;
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.center,
      child: SizedBox(
        width: maxWidth,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            PressableButton(
              onTap: () => _openShop(context),
              child: _buildTopIcon(
                'assets/images/main_screen/icon_shop.png',
                shopW,
                shopH,
              ),
            ),
            SizedBox(width: gap),
            PressableButton(
              onTap: () {
                SettingsService.hapticLightImpact();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const RoadOfLuckScreen(),
                  ),
                );
              },
              child: _buildTopIcon(
                'assets/images/main_screen/icon_road_of_luck.png',
                roadW,
                roadH,
              ),
            ),
            SizedBox(width: gap),
            MinersPassButton(
              width: minersW,
              height: minersH,
              scale: layout.scale,
              source: 'vip',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceText(String value, double scale) {
    const strokeColor = Color(0x40000000);
    const fillColor = Color(0xFFFFFFFF);
    final baseStyle = GoogleFonts.montserrat(
      color: fillColor,
      fontSize: 18.58 * scale,
      fontWeight: FontWeight.w900,
      height: 1.6,
      letterSpacing: -0.02 * 18.58 * scale,
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

  Widget _buildBalance(BuildContext context, double scale) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: _balanceBgWidth * scale,
          height: _balanceBgHeight * scale,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(8 * scale)),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8 * scale),
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
                    offset: const Offset(0, -5),
                    child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Transform.translate(
                        offset: const Offset(0, 2),
                        child: SizedBox(
                          width: _coinSize * scale,
                          height: _coinSize * scale,
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
                      ),
                      SizedBox(width: 8 * scale),
                      SizedBox(
                        width: 80 * scale,
                        height: 30 * scale,
                        child: ValueListenableBuilder<int>(
                          valueListenable: BalanceService.balanceNotifier,
                          builder: (context, value, _) {
                            return Center(
                              child: _AnimatedBalanceText(
                                targetValue: value,
                                formatBalance: _formatBalance,
                                buildBalanceText: (v) => _buildBalanceText(v, scale),
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
          top: _balanceBgHeight * scale - _addBtnHeight / 2 * scale - _addBtnRaise * scale,
          left: (_balanceBgWidth * scale - _addBtnWidth * scale) / 2,
          child: PressableButton(
            onTap: () {
              SettingsService.hapticLightImpact();
              _openShop(context);
            },
            child: SizedBox(
              width: _addBtnWidth * scale,
              height: _addBtnHeight * scale,
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
        ),
      ],
    );
  }

  Widget _buildLogo(BuildContext context, double scale) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Center(
          child: SizedBox(
            width: _logoWidth * scale,
            height: _logoHeight * scale,
            child: Image.asset(
              'assets/images/main_screen/logo.png',
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => Container(
                color: Colors.amber.withValues(alpha: 0.3),
                child: Icon(Icons.image_not_supported, size: _logoWidth * scale * 0.3),
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
                SettingsService.hapticLightImpact();
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
                    child: Icon(Icons.settings, size: _settingsIconWidth * scale * 0.8),
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
    if (_tutorialStateLoaded && _showTutorialStepOne && index != _tutorialGameIndex) return;
    SettingsService.hapticLightImpact();
    if (index == _tutorialGameIndex) {
      if (_tutorialStateLoaded && _showTutorialStepOne) {
        await _completeTutorialStepOne();
      }
      if (!context.mounted) return;
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const GoldVeinScreen()));
      return;
    }
    if (index == _goldenAvalancheIndex) {
      await AudioService.instance.warmUpGoldenAvalanchePegClicks();
      if (!context.mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const GoldenAvalancheScreen()),
      );
      return;
    }
    if (index == 4) {
      unawaited(AudioService.instance.ensureMinersWheelSpinLoaded());
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
        MaterialPageRoute(builder: (_) => const ChiefTrollsWheelScreen()),
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
        MaterialPageRoute(builder: (_) => const CardMine21Screen()),
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
    double size,
    double scale,
  ) {
    return PressableButton(
      onTap: () => _onGameTap(context, index),
      pressedScale: 0.95,
      pressedOffset: const Offset(0, 1.8),
      duration: const Duration(milliseconds: 120),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: const Color(0xFF2D2418),
          borderRadius: BorderRadius.circular(13 * scale),
          boxShadow: [
            BoxShadow(
              color: _gameShadowColor,
              blurRadius: 14.13 * scale,
              spreadRadius: 4.68 * scale,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(13 * scale),
          child: Transform.scale(
            scale: 1.015,
            child: Image.asset(
              imagePath,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => Container(
              color: Colors.amber.withValues(alpha: 0.3),
              child: Icon(Icons.casino, size: 48, color: Colors.amber.shade700),
            ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGamesGridContent(BuildContext context, double scale) {
    final screenWidth = MediaQuery.of(context).size.width;
    final layout = _gamesGridLayout(screenWidth, scale);
    _lastGamesGridLayout = layout;
    return Padding(
      key: _gamesGridKey,
      padding: EdgeInsets.symmetric(horizontal: layout.margin),
      child: Column(
        children: [
          for (var i = 0; i < _gameAssets.length; i += 2)
            Padding(
              padding: EdgeInsets.only(
                bottom: i + 2 < _gameAssets.length ? layout.verticalGap : 0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Opacity(
                    opacity: (i == _tutorialGameIndex && _showTutorialStepOne) ? 0 : 1,
                    child: _showTutorialStepOne && i == _tutorialGameIndex
                        ? KeyedSubtree(
                            key: _goldVeinTutorialTargetKey,
                            child: _buildGameButton(
                              context,
                              _gameAssets[i].$1,
                              _gameAssets[i].$2,
                              i,
                              layout.size,
                              scale,
                            ),
                          )
                        : _buildGameButton(
                            context,
                            _gameAssets[i].$1,
                            _gameAssets[i].$2,
                            i,
                            layout.size,
                            scale,
                          ),
                  ),
                  SizedBox(width: layout.gap),
                  _buildGameButton(
                    context,
                    _gameAssets[i + 1].$1,
                    _gameAssets[i + 1].$2,
                    i + 1,
                    layout.size,
                    scale,
                  ),
                ],
              ),
            ),
        ],
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

  Widget _buildTutorialFirstCard(BuildContext context, double layoutScale) {
    final r = _tutorialGoldVeinRect;
    if (r == null) return const SizedBox.shrink();
    const pad = 5.0;
    return Positioned(
      left: r.left - pad,
      top: r.top - pad,
      width: r.width + 2 * pad,
      height: r.height + 2 * pad,
      child: AnimatedBuilder(
        animation: _tutorialPulseController,
        builder: (context, child) {
          final t = Curves.easeInOut.transform(_tutorialPulseController.value);
          final pulseScale =
              _tutorialCardScaleMin +
              (_tutorialCardScaleMax - _tutorialCardScaleMin) * t;
            return Transform.scale(
            scale: pulseScale,
            child: Container(
              width: r.width + 2 * pad,
              height: r.height + 2 * pad,
              decoration: BoxDecoration(
                  color: const Color(0xFF2D2418),
                borderRadius: BorderRadius.circular(13 * layoutScale),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xE0FFF145).withValues(alpha: 0.85),
                    blurRadius: (18 + (8 * t)) * layoutScale,
                    spreadRadius: (3 + (2 * t)) * layoutScale,
                  ),
                ],
              ),
              child: PressableButton(
                onTap: () => _onGameTap(context, _tutorialGameIndex),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(13 * layoutScale),
                  child: Transform.scale(
                    scale: 1.015,
                    child: Image.asset(_gameAssets[_tutorialGameIndex].$1, fit: BoxFit.contain),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  static const _tutorialBubbleScale = 0.85;

  Widget _buildTutorialOverlay(BuildContext context, double scale) {
    final screenWidth = MediaQuery.of(context).size.width;
    final layout = _gamesGridLayout(screenWidth, scale);
    final cardSize = layout.size + 10;
    final rowOffset = _tutorialGameIndex ~/ 2 * (layout.size + layout.verticalGap);
    final bubbleWidth = _tutorialBubbleWidth * _tutorialBubbleScale * scale;
    final bubbleHeight = _tutorialBubbleHeight * _tutorialBubbleScale * scale;
    final r = _tutorialGoldVeinRect;
    final double bubbleTop;
    final double bubbleLeft;
    if (r != null) {
      bubbleTop = r.bottom + 12 * scale;
      bubbleLeft = (r.center.dx - bubbleWidth / 2)
          .clamp(8.0, screenWidth - bubbleWidth - 8);
    } else {
      bubbleTop =
          _gamesTopOffset(context, scale) +
          _gamesTopGlowPadding * scale -
          20 * scale +
          rowOffset +
          cardSize +
          40 * scale;
      bubbleLeft =
          (screenWidth - bubbleWidth) / 2 - 90 * scale + 20 * scale - 15 * scale;
    }
    return Positioned.fill(
      child: Stack(
        key: _tutorialOverlayStackKey,
        children: [
          const Positioned.fill(
            child: AbsorbPointer(
              absorbing: true,
              child: ColoredBox(color: _tutorialOverlayColor),
            ),
          ),
          _buildTutorialFirstCard(context, scale),
          Positioned(
            left: 0,
            right: 0,
            bottom: _tutorialTrollBottom,
            child: Align(
              alignment: Alignment.bottomCenter,
                child: Transform.translate(
                offset: Offset(60 * scale, 45 * scale),
                child: IgnorePointer(
                  child: SizedBox(
                    width: _tutorialTrollSize * scale,
                    height: _tutorialTrollSize * scale,
                    child: Image.asset(
                      'assets/images/tutorial/troll_education.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: bubbleLeft,
            top: bubbleTop,
            child: SizedBox(
              width: bubbleWidth,
              height: bubbleHeight,
              child: Stack(
                alignment: Alignment.center,
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    'assets/images/tutorial/info_back.png',
                    fit: BoxFit.fill,
                  ),
                  Center(
                    child: Transform.translate(
                      offset: const Offset(0, -3),
                      child: Text(
                        'Tap to play!',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.gothicA1(
                          color: const Color(0xFFFFFFFF),
                          fontSize: _tutorialTextSize * _tutorialBubbleScale * scale,
                          fontWeight: FontWeight.w900,
                          height: 1.6,
                          letterSpacing: -0.02 * _tutorialTextSize * _tutorialBubbleScale * scale,
                        ),
                      ),
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
    final isCurrent = ModalRoute.of(context)?.isCurrent ?? false;
    if (isCurrent && !_wasCurrentRoute) {
      _wasCurrentRoute = true;
      _scheduleIdleScrollAfterDelay();
    } else if (!isCurrent) {
      _wasCurrentRoute = false;
      _idleScrollDelayTimer?.cancel();
      _idleScrollDelayTimer = null;
    }
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final scale = min(
            constraints.maxWidth / _designWidth,
            constraints.maxHeight / _designHeight,
          ).clamp(0.82, 1.3);
          return Stack(
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
              NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  if (notification is ScrollStartNotification &&
                      notification.dragDetails != null) {
                    final wasAutoScrolling = _gamesAutoScrollRunning;
                    _pauseGamesAutoScrollForUserInteraction();
                    if (wasAutoScrolling) {
                      _openGameAtScrollTouch(context, notification.dragDetails!);
                    }
                  } else if (notification is ScrollUpdateNotification &&
                      notification.dragDetails != null) {
                    _pauseGamesAutoScrollForUserInteraction();
                  }
                  return false;
                },
                child: SafeArea(
                  child: SingleChildScrollView(
                    controller: _mainScrollController,
                    child: Column(
                      children: [
                        SizedBox(height: _topIconsTop * scale),
                        LayoutBuilder(
                          builder: (context, innerConstraints) {
                            final w = innerConstraints.maxWidth.isFinite
                                ? innerConstraints.maxWidth
                                : constraints.maxWidth;
                            return _buildTopIconsRowContent(
                              context,
                              w - 48 * scale,
                              scale,
                            );
                          },
                        ),
                        SizedBox(height: _logoTopGap * scale),
                        SizedBox(
                          width: double.infinity,
                          height: _logoHeight * scale,
                          child: _buildLogo(context, scale),
                        ),
                        SizedBox(height: _balanceTopGap * scale),
                        Center(
                          child: PressableButton(
                            onTap: () {
                              SettingsService.hapticLightImpact();
                              _openShop(context);
                            },
                            child: _buildBalance(context, scale),
                          ),
                        ),
                        SizedBox(height: _gamesTopGlowPadding * scale),
                        _buildGamesGridContent(context, scale),
                        SizedBox(height: 24 * scale),
                      ],
                    ),
                  ),
                ),
              ),
              if (_tutorialStateLoaded && _showTutorialStepOne)
                _buildTutorialOverlay(context, scale),
            ],
          );
        },
      ),
    );
  }
}
