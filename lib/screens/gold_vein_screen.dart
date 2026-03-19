import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gold_mine_trolls/widgets/miners_pass_button.dart';
import 'package:gold_mine_trolls/screens/shop_screen.dart';
import 'package:gold_mine_trolls/services/analytics_service.dart';
import 'package:gold_mine_trolls/services/audio_service.dart';
import 'package:gold_mine_trolls/services/balance_service.dart';
import 'package:gold_mine_trolls/services/tutorial_service.dart';
import 'package:gold_mine_trolls/screens/info_screen.dart';
import 'package:gold_mine_trolls/widgets/gold_vein_info_content.dart';
import 'package:gold_mine_trolls/screens/gold_vein_constants.dart';
import 'package:gold_mine_trolls/widgets/pressable_button.dart';
import 'package:gold_mine_trolls/widgets/warning_panel.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum _WinBannerType { win, bigWin, jackpots }

class GoldVeinScreen extends StatefulWidget {
  const GoldVeinScreen({super.key});

  @override
  State<GoldVeinScreen> createState() => _GoldVeinScreenState();
}

class _GoldVeinScreenState extends State<GoldVeinScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  static const _gameName = 'gold_vein';
  static const _rows = 5;
  static const _cols = 3;
  static const _betStep = 50;
  static const _minBet = 50;
  static const _baseBet = 10000;
  static const _balanceStroke = Color(0x40000000);
  static const _balanceFill = Color(0xFFFFFFFF);
  static const _slotBoardWidth = GoldVeinSlotZones.viewWidth;
  static const _slotBoardHeight = GoldVeinSlotZones.viewHeight;
  static const _slotSymbolWidth = 60.0;
  static const _slotSymbolHeight = 48.0;
  static const _tutorialOverlayColor = Color(0xB36D2E11);
  static const _tutorialBubbleWidth = 209.0;
  static const _tutorialBubbleHeight = 80.0;
  static const _tutorialBubbleStep3Width = 230.0;
  static const _tutorialTrollSize = 280.0;
  /// Step 3 overlay: visual troll size vs base layout (try 2.0 for adaptive preview).
  static const _tutorialStep3TrollScale = 2.0;
  static const _tutorialStep1DoneKey = 'tutorial_step_1_done';
  static const _tutorialStep2DoneKey = 'tutorial_step_2_done';
  static const _tutorialStep3DoneKey = 'tutorial_step_3_done';
  static const _postTutorialJackpotGivenKey = 'gold_vein_post_tutorial_jackpot_given';

  final Random _rng = Random();
  late final AnimationController _winPulseController;
  late final AnimationController _notificationController;
  late final AnimationController _winCountController;
  late final AnimationController _balanceCountController;
  late final AnimationController _tutorialTapController;
  late final List<AnimationController> _reelBounceControllers;

  Timer? _notificationHideTimer;
  Timer? _adjustTimer;
  Stopwatch? _adjustWatch;

  int _balance = 0;
  int _displayBalance = 0;
  double _balanceAnimFrom = 0;
  int _bet = _baseBet;
  int _lastWin = 0;
  bool _isSpinning = false;
  bool _autoSpin = false;
  int _activeDelta = 0;
  bool _loadingBalance = true;
  int _tutorialStep = 0;
  bool _tutorialStateLoaded = false;
  bool _goldVeinTutorialCompleted = false;
  bool _postTutorialJackpotGiven = false;
  int _spinsSinceEntry = 0;

  /// Guaranteed 1 win per 4 spins. Which spin wins is random; after a win, next 3 are losses.
  static const _winChanceOutOf = 4;
  int _spinsInCycle = 0; // 0..3, which spin in current cycle
  int _winningSpinInCycle = 0; // 0..3, chosen at cycle start

  String _centerMessage = '';
  bool _isCenterWin = false;
  bool _showCenterMessage = false;
  bool _isWinOverlayVisible = false;
  _WinBannerType _winBannerType = _WinBannerType.win;
  int _overlayTargetWin = 0;
  int _overlayAnimatedWin = 0;

  final List<List<int>> _matrix = List.generate(
    _rows,
    (_) => List.generate(_cols, (_) => 0),
  );

  final List<int> _reelTicks = [0, 0, 0];
  final List<double> _reelProgress = [0, 0, 0];
  final Set<String> _highlightedCells = <String>{};

  // 5 paylines for 3x5 view: top, middle, bottom, and 2 diagonals.
  final List<List<({int r, int c})>> _paylines = const [
    [(r: 0, c: 0), (r: 0, c: 1), (r: 0, c: 2)],
    [(r: 2, c: 0), (r: 2, c: 1), (r: 2, c: 2)],
    [(r: 4, c: 0), (r: 4, c: 1), (r: 4, c: 2)],
    [(r: 1, c: 0), (r: 2, c: 1), (r: 3, c: 2)],
    [(r: 3, c: 0), (r: 2, c: 1), (r: 1, c: 2)],
  ];

  final List<String> _symbols = const [
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

  // Higher weight -> more frequent symbol. All symbols positive; high-value (big wins) rarer.
  final List<int> _symbolWeights = const [
    1,  // 1.1: 10x — very rare
    12,
    14,
    10,
    16,
    8,
    1,  // 1.7: 6.5x — very rare
    4,
    1,  // 1.9: 8.2x — very rare
    6,
    1,  // 1.11: 4.8x — very rare
    9,
  ];

  // Payout multipliers per payline (3 matching symbols) — all positive, matches info screen.
  final List<double> _symbolMultipliers = const [
    10.0, // 1.1
    1.3, // 1.2
    1.4, // 1.3
    1.6, // 1.4
    1.1, // 1.5
    2.6, // 1.6
    6.5, // 1.7
    3.5, // 1.8
    8.2, // 1.9
    1.8, // 1.10
    4.8, // 1.11
    2.3, // 1.12
  ];

  /// Jackpot: all 15 cells same symbol. Odds 1:1000.
  static const _jackpotOdds = 1000;

  /// Jackpot payout multiplier (bet × this).
  static const _jackpotMultiplier = 100.0;

  /// Symbol index for diamond (1.9.png) — used for post-tutorial fixed win.
  static const _diamondSymbolIndex = 8;

  /// Fixed jackpot amount after tutorial completion.
  static const _postTutorialJackpot = 10000;

  final GlobalKey _tutorialStep3SpinKey = GlobalKey();
  final GlobalKey _tutorialStep3OverlayKey = GlobalKey();
  final ScrollController _goldVeinScrollController = ScrollController();
  Rect? _tutorialStep3SpinRect;
  bool _tutorialStep3ScrollAttached = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(AnalyticsService.reportGameStart(_gameName));
    _winPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _notificationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _winCountController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 900),
        )..addListener(() {
          if (!mounted || !_isWinOverlayVisible) return;
          final t = Curves.easeOutCubic.transform(_winCountController.value);
          setState(() => _overlayAnimatedWin = (_overlayTargetWin * t).round());
        });
    _balanceCountController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 520),
        )..addListener(() {
          if (!mounted) return;
          final t = Curves.easeOutCubic.transform(
            _balanceCountController.value,
          );
          final next =
              (ui.lerpDouble(_balanceAnimFrom, _balance.toDouble(), t) ??
                      _balance.toDouble())
                  .round();
          if (next == _displayBalance) return;
          setState(() => _displayBalance = next);
        });
    _tutorialTapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _reelBounceControllers = List.generate(
      _cols,
      (_) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 220),
      ),
    );
    _seedInitialMatrix();
    BalanceService.balanceNotifier.addListener(_onBalanceNotifierChanged);
    _loadBalance();
    _loadTutorialState();
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    if (_tutorialStep == 3) _scheduleSyncTutorialStep3Spin();
  }

  void _scheduleSyncTutorialStep3Spin() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _tutorialStep != 3) return;
      _syncTutorialStep3Spin();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _tutorialStep != 3) return;
        _syncTutorialStep3Spin();
      });
    });
  }

  void _syncTutorialStep3Spin() {
    final targetCtx = _tutorialStep3SpinKey.currentContext;
    final overlayCtx = _tutorialStep3OverlayKey.currentContext;
    if (targetCtx == null || overlayCtx == null) return;
    final spinBox = targetCtx.findRenderObject() as RenderBox?;
    final overlayBox = overlayCtx.findRenderObject() as RenderBox?;
    if (spinBox == null ||
        overlayBox == null ||
        !spinBox.hasSize ||
        !overlayBox.hasSize) {
      return;
    }
    final topLeft = overlayBox.globalToLocal(
      spinBox.localToGlobal(Offset.zero),
    );
    final newRect = Rect.fromLTWH(
      topLeft.dx,
      topLeft.dy,
      spinBox.size.width,
      spinBox.size.height,
    );
    if (_tutorialStep3SpinRect == null ||
        (_tutorialStep3SpinRect!.left - newRect.left).abs() > 0.5 ||
        (_tutorialStep3SpinRect!.top - newRect.top).abs() > 0.5 ||
        (_tutorialStep3SpinRect!.width - newRect.width).abs() > 0.5 ||
        (_tutorialStep3SpinRect!.height - newRect.height).abs() > 0.5) {
      setState(() => _tutorialStep3SpinRect = newRect);
    }
  }

  void _attachTutorialStep3ScrollSync() {
    if (_tutorialStep3ScrollAttached) return;
    _tutorialStep3ScrollAttached = true;
    _goldVeinScrollController.addListener(_scheduleSyncTutorialStep3Spin);
  }

  void _detachTutorialStep3ScrollSync() {
    if (!_tutorialStep3ScrollAttached) return;
    _tutorialStep3ScrollAttached = false;
    _goldVeinScrollController.removeListener(_scheduleSyncTutorialStep3Spin);
  }

  void _onBalanceNotifierChanged() {
    if (!mounted) return;
    final v = BalanceService.balanceNotifier.value;
    if (v != _balance) {
      setState(() {
        _balance = v;
        _displayBalance = v;
        _balanceAnimFrom = v.toDouble();
      });
      _animateBalanceChange(durationMs: 520);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _detachTutorialStep3ScrollSync();
    _goldVeinScrollController.dispose();
    BalanceService.balanceNotifier.removeListener(_onBalanceNotifierChanged);
    _adjustTimer?.cancel();
    _notificationHideTimer?.cancel();
    _winPulseController.dispose();
    _notificationController.dispose();
    _winCountController.dispose();
    _balanceCountController.dispose();
    _tutorialTapController.dispose();
    for (final c in _reelBounceControllers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadBalance() async {
    final value = await BalanceService.getBalance();
    final initialBet = value > 0
        ? (value * 0.05).round().clamp(_minBet, value)
        : _minBet;
    if (!mounted) return;
    setState(() {
      _balance = value;
      _displayBalance = value;
      _balanceAnimFrom = value.toDouble();
      _bet = initialBet;
      _loadingBalance = false;
    });
    unawaited(BalanceService.setLastBet(initialBet));
  }

  Future<void> _loadTutorialState() async {
    final rawCompleted = await TutorialService.isTutorialsCompletedRaw();
    final force = TutorialService.forceTutorialForTesting;
    final tutorialsCompleted = force ? false : rawCompleted;

    final prefs = await SharedPreferences.getInstance();
    // Step 1 = «зашли в Gold Vein с главного» (тот же ключ, что на Home). Его нельзя
    // форсить в false — иначе _tutorialStep всегда 0 и оверлеи 2/3 никогда не показываются.
    final step1Done = prefs.getBool(_tutorialStep1DoneKey) ?? false;
    final step2Done =
        force ? false : (prefs.getBool(_tutorialStep2DoneKey) ?? false);
    final step3Done =
        force ? false : (prefs.getBool(_tutorialStep3DoneKey) ?? false);
    final jackpotGiven = force
        ? false
        : (prefs.getBool(_postTutorialJackpotGivenKey) ?? false);
    if (!mounted) return;
    setState(() {
      _goldVeinTutorialCompleted = tutorialsCompleted;
      _postTutorialJackpotGiven = jackpotGiven;
      if (tutorialsCompleted) {
        _tutorialStep = 0;
      } else if (!step1Done) {
        // В тестовом режиме можно открыть Gold Vein без главного экрана — всё равно показать шаг 2.
        _tutorialStep = force ? 2 : 0;
      } else if (!step2Done) {
        _tutorialStep = 2;
      } else if (!step3Done) {
        _tutorialStep = 3;
      } else {
        _tutorialStep = 0;
      }
      _tutorialStateLoaded = true;
    });
    if (mounted && _tutorialStep == 3) {
      _attachTutorialStep3ScrollSync();
      _scheduleSyncTutorialStep3Spin();
    }
  }

  Future<void> _completeTutorialStepTwo() async {
    final prefs = await SharedPreferences.getInstance();
    // Если зашли в обучение без тапа по карточке на главном — зафиксировать шаг 1,
    // иначе при следующей загрузке снова попадём только на шаг 2.
    if (!(prefs.getBool(_tutorialStep1DoneKey) ?? false)) {
      await prefs.setBool(_tutorialStep1DoneKey, true);
    }
    await prefs.setBool(_tutorialStep2DoneKey, true);
    if (!mounted) return;
    setState(() {
      _tutorialStep = 3;
      _tutorialStep3SpinRect = null;
    });
    _attachTutorialStep3ScrollSync();
    _scheduleSyncTutorialStep3Spin();
  }

  Future<void> _completeTutorialStepThree() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_tutorialStep3DoneKey, true);
    await TutorialService.setTutorialsCompleted();
    if (!mounted) return;
    _detachTutorialStep3ScrollSync();
    setState(() {
      _tutorialStep = 0;
      _goldVeinTutorialCompleted = true;
      _tutorialStep3SpinRect = null;
    });
  }

  void _animateBalanceChange({int durationMs = 520}) {
    _balanceCountController.stop();
    _balanceAnimFrom = _displayBalance.toDouble();
    _balanceCountController.duration = Duration(milliseconds: durationMs);
    _balanceCountController.forward(from: 0);
  }

  void _seedInitialMatrix() {
    for (var r = 0; r < _rows; r++) {
      for (var c = 0; c < _cols; c++) {
        _matrix[r][c] = _weightedRandomSymbol();
      }
    }
  }

  int _weightedRandomSymbol() {
    final total = _symbolWeights.fold<int>(0, (sum, w) => sum + w);
    var target = _rng.nextInt(total);
    for (var i = 0; i < _symbolWeights.length; i++) {
      target -= _symbolWeights[i];
      if (target < 0) return i;
    }
    return 0;
  }

  void _openShop() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close shop',
      barrierColor: const Color(0x80000000),
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, animation, secondaryAnimation) =>
          const ShopScreen(source: 'gold_vein'),
    );
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

  String _formatWinAmount(int value) {
    final s = value.toString();
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
      b.write(s[i]);
    }
    return b.toString();
  }

  TextStyle _valueTextStyle({
    Color? color,
    Paint? foreground,
    double size = 18.58,
    double? letterSpacing,
  }) {
    return TextStyle(
      fontFamily: 'Gotham',
      color: foreground == null ? color : null,
      foreground: foreground,
      fontSize: size,
      fontWeight: FontWeight.w900,
      fontStyle: FontStyle.normal,
      height: 1.6,
      letterSpacing: letterSpacing ?? -0.02 * size,
      shadows: [
        const Shadow(
          color: _balanceStroke,
          offset: Offset(0, 1.74),
          blurRadius: 0,
        ),
      ],
    );
  }

  void _showCenterResult(String message, {required bool isWin}) {
    _notificationHideTimer?.cancel();
    _notificationController.forward(from: 0);
    setState(() {
      _centerMessage = message;
      _isCenterWin = isWin;
      _showCenterMessage = true;
    });
    SystemSound.play(SystemSoundType.alert);
    HapticFeedback.lightImpact();
    _notificationHideTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      _notificationController.reverse();
      setState(() => _showCenterMessage = false);
    });
  }

  void _showWinOverlay({required int amount, required _WinBannerType type}) {
    _notificationHideTimer?.cancel();
    _notificationController.forward(from: 0);

    final countMs = switch (type) {
      _WinBannerType.win => 800,
      _WinBannerType.bigWin => 1050,
      _WinBannerType.jackpots => 2200,
    };

    setState(() {
      _showCenterMessage = false;
      _isWinOverlayVisible = true;
      _winBannerType = type;
      _overlayTargetWin = amount;
      _overlayAnimatedWin = 0;
    });
    _winCountController.duration = Duration(milliseconds: countMs);
    _winCountController.forward(from: 0);

    const hideMs = 2000;
    _notificationHideTimer = Timer(const Duration(milliseconds: hideMs), () {
      if (!mounted) return;
      _dismissWinOverlay();
    });
  }

  void _dismissWinOverlay() {
    if (!_isWinOverlayVisible) return;
    _notificationController.reverse();
    setState(() => _isWinOverlayVisible = false);
    if (_autoSpin && !_isSpinning) {
      unawaited(_startSpin());
    }
  }

  Future<void> _startSpin() async {
    if (_isSpinning) return;
    if (_bet <= 0) return;
    if (_balance < _bet) {
      showWarningSnackBar(context, 'Not enough coins to start the game.');
      setState(() => _autoSpin = false);
      return;
    }

    unawaited(AudioService.instance.playButtonClick());
    // Звук запускаем асинхронно: анимация не ждёт его завершения.
    unawaited(AudioService.instance.playRouletteSpin(3800));

    final betToUse = _bet;
    final afterBetBalance = _balance - betToUse;
    setState(() {
      _isSpinning = true;
      _highlightedCells.clear();
      _balance = afterBetBalance;
      _reelProgress
        ..[0] = 0
        ..[1] = 0
        ..[2] = 0;
    });
    _animateBalanceChange(durationMs: 420);
    await BalanceService.setBalance(_balance);

    _spinsSinceEntry++;
    final target = _generateSpinResult();

    await Future.wait([
      _spinReel(0, target, _spinDurationForReel(0)),
      _spinReel(1, target, _spinDurationForReel(1)),
      _spinReel(2, target, _spinDurationForReel(2)),
    ]);

    if (!mounted) return;
    final result = _calculateWin(target, betToUse);
    var win = result.$1;
    final totalMultiplier = result.$2;
    final winCells = result.$3;
    var winningLines = result.$4;
    var isJackpot = result.$5;
    final isPostTutorialWin =
        _spinsSinceEntry == 1 &&
        win > 0 &&
        _goldVeinTutorialCompleted &&
        !_postTutorialJackpotGiven;
    if (isPostTutorialWin) {
      win = _postTutorialJackpot;
      isJackpot = true;
      _postTutorialJackpotGiven = true;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_postTutorialJackpotGivenKey, true);
    }

    setState(() {
      _highlightedCells
        ..clear()
        ..addAll(winCells);
      _lastWin = win;
      _isSpinning = false;
      _reelProgress
        ..[0] = 1
        ..[1] = 1
        ..[2] = 1;
    });

    if (win > 0) {
      unawaited(AnalyticsService.reportGameWin(_gameName));
      unawaited(AudioService.instance.playWin());
      _winPulseController.repeat(reverse: true);
      _balance += win;
      _animateBalanceChange(durationMs: 760);
      await BalanceService.setBalance(_balance);
      // Big wins only 1 in 100 — downgrade to regular win when not selected.
      final wouldBeBigWin = totalMultiplier >= 5 || winningLines >= 3;
      final allowBigWin = _rng.nextInt(100) == 0; // 1 in 100
      final isBigWin = wouldBeBigWin && allowBigWin;
      _showWinOverlay(
        amount: win,
        type: isJackpot
            ? _WinBannerType.jackpots
            : (isBigWin ? _WinBannerType.bigWin : _WinBannerType.win),
      );
    } else {
      unawaited(AnalyticsService.reportGameLoss(_gameName));
      _winPulseController.stop();
      _winPulseController.value = 0;
      _notificationHideTimer?.cancel();
      setState(() => _isWinOverlayVisible = false);
    }

    if (_autoSpin && !_isSpinning && !_isWinOverlayVisible && mounted) {
      await Future.delayed(const Duration(milliseconds: 350));
      if (mounted && _autoSpin && !_isWinOverlayVisible) {
        unawaited(_startSpin());
      }
    }
  }

  int _spinDurationForReel(int reel) {
    switch (reel) {
      case 0:
        return 980;
      case 1:
        return 2500;
      case 2:
        return 1650;
      default:
        return 1500;
    }
  }

  ({
    int minStepMs,
    int maxStepMs,
    Curve curve,
    int settleBaseMs,
    int settleStepMs,
  })
  _spinProfileForReel(int reel) {
    // Same start speed (minStepMs) for all; different deceleration (maxStepMs)
    switch (reel) {
      case 0:
        return (
          minStepMs: 18,
          maxStepMs: 82,
          curve: Curves.easeOutCubic,
          settleBaseMs: 58,
          settleStepMs: 16,
        );
      case 1:
        return (
          minStepMs: 18,
          maxStepMs: 128,
          curve: Curves.easeOutQuart,
          settleBaseMs: 84,
          settleStepMs: 26,
        );
      case 2:
        return (
          minStepMs: 18,
          maxStepMs: 104,
          curve: Curves.easeOutQuad,
          settleBaseMs: 68,
          settleStepMs: 20,
        );
      default:
        return (
          minStepMs: 18,
          maxStepMs: 100,
          curve: Curves.easeOutCubic,
          settleBaseMs: 64,
          settleStepMs: 18,
        );
    }
  }

  Future<void> _spinReel(
    int reel,
    List<List<int>> target,
    int durationMs,
  ) async {
    final profile = _spinProfileForReel(reel);

    final started = DateTime.now();
    while (true) {
      final elapsedMs = DateTime.now().difference(started).inMilliseconds;
      if (elapsedMs >= durationMs) break;
      if (!mounted) return;

      final progress = (elapsedMs / durationMs).clamp(0.0, 1.0);
      final eased = profile.curve.transform(progress);
      final stepMs =
          (profile.minStepMs + (profile.maxStepMs - profile.minStepMs) * eased)
              .round();
      final topSymbol = _weightedRandomSymbol();

      setState(() {
        _shiftReelDown(reel, topSymbol: topSymbol);
        _reelTicks[reel]++;
        _reelProgress[reel] = progress;
      });
      await Future.delayed(Duration(milliseconds: stepMs));
    }

    for (var settleStep = 0; settleStep < _rows; settleStep++) {
      if (!mounted) return;
      setState(() {
        final topSymbol = target[_rows - 1 - settleStep][reel];
        _shiftReelDown(reel, topSymbol: topSymbol);
        _reelTicks[reel]++;
        _reelProgress[reel] = 0.90 + ((settleStep + 1) / _rows) * 0.10;
      });
      await Future.delayed(
        Duration(
          milliseconds:
              profile.settleBaseMs + settleStep * profile.settleStepMs,
        ),
      );
    }
    if (mounted) {
      setState(() => _reelProgress[reel] = 1);
    }
    _reelBounceControllers[reel].forward(from: 0);
  }

  void _shiftReelDown(int reel, {required int topSymbol}) {
    for (var r = _rows - 1; r > 0; r--) {
      _matrix[r][reel] = _matrix[r - 1][reel];
    }
    _matrix[0][reel] = topSymbol;
  }

  List<List<int>> _generateSpinResult() {
    // During tutorial: no wins.
    final inTutorial = _tutorialStep == 2 || _tutorialStep == 3;
    final isFirstSpinAfterTutorial =
        _spinsSinceEntry == 1 &&
        _goldVeinTutorialCompleted &&
        !_postTutorialJackpotGiven;

    // Guaranteed 1 win per 4 spins. At cycle start, pick which spin (0..3) wins.
    if (!inTutorial && _spinsInCycle == 0) {
      _winningSpinInCycle = _rng.nextInt(_winChanceOutOf);
    }
    final isWinningSpin = !inTutorial &&
        (isFirstSpinAfterTutorial || _spinsInCycle == _winningSpinInCycle);

    if (!isWinningSpin) {
      if (!inTutorial) _spinsInCycle = (_spinsInCycle + 1) % _winChanceOutOf;
      return _generateLosingGrid();
    }

    // First spin after tutorial: fixed jackpot with 3 diamonds (middle line) + 10000 payout.
    if (isFirstSpinAfterTutorial) {
      _spinsInCycle = (_spinsInCycle + 1) % _winChanceOutOf;
      final grid = List.generate(
        _rows,
        (_) => List.generate(_cols, (_) => _weightedRandomSymbol()),
      );
      for (var c = 0; c < _cols; c++) {
        grid[2][c] = _diamondSymbolIndex;
      }
      return grid;
    }

    // On winning spins: jackpot 1 in 1000, or guaranteed line win.
    if (_rng.nextInt(_jackpotOdds) == 0) {
      _spinsInCycle = (_spinsInCycle + 1) % _winChanceOutOf;
      final jackpotSymbol = _rng.nextInt(_symbols.length);
      return List.generate(
        _rows,
        (_) => List.generate(_cols, (_) => jackpotSymbol),
      );
    }

    _spinsInCycle = (_spinsInCycle + 1) % _winChanceOutOf;
    final grid = List.generate(
      _rows,
      (_) => List.generate(_cols, (_) => _weightedRandomSymbol()),
    );
    final line = _paylines[_rng.nextInt(_paylines.length)];
    // Random symbol for winning line (uniform), so multiplier is random.
    final symbol = _rng.nextInt(_symbols.length);
    for (final p in line) {
      grid[p.r][p.c] = symbol;
    }
    return grid;
  }

  List<List<int>> _generateLosingGrid() {
    var grid = List.generate(
      _rows,
      (_) => List.generate(_cols, (_) => _weightedRandomSymbol()),
    );
    // Break winning paylines: change one cell per winning line until none win.
    for (var pass = 0; pass < 5; pass++) {
      var anyWin = false;
      for (final line in _paylines) {
        final symbol = grid[line[0].r][line[0].c];
        final s1 = grid[line[1].r][line[1].c];
        final s2 = grid[line[2].r][line[2].c];
        if (symbol == s1 && symbol == s2) {
          anyWin = true;
          var otherSymbol = _rng.nextInt(_symbols.length);
          if (otherSymbol == symbol) otherSymbol = (symbol + 1) % _symbols.length;
          grid[line[1].r][line[1].c] = otherSymbol;
        }
      }
      if (!anyWin) break;
    }
    return grid;
  }

  (int, double, Set<String>, int, bool) _calculateWin(
    List<List<int>> grid,
    int bet,
  ) {
    // Jackpot: all 15 cells same symbol — fixed payout.
    final firstSymbol = grid[0][0];
    var isJackpot = true;
    for (var r = 0; r < _rows; r++) {
      for (var c = 0; c < _cols; c++) {
        if (grid[r][c] != firstSymbol) {
          isJackpot = false;
          break;
        }
      }
      if (!isJackpot) break;
    }
    if (isJackpot) {
      final win = (bet * _jackpotMultiplier).round();
      final allCells = <String>{};
      for (var r = 0; r < _rows; r++) {
        for (var c = 0; c < _cols; c++) {
          allCells.add('$r-$c');
        }
      }
      return (win, _jackpotMultiplier, allCells, 5, true);
    }

    // Regular paylines: best line wins (bet × max multiplier), not sum of lines.
    var totalMultiplier = 0.0;
    final hitCells = <String>{};
    var winningLines = 0;
    for (final line in _paylines) {
      final symbol = grid[line[0].r][line[0].c];
      final s1 = grid[line[1].r][line[1].c];
      final s2 = grid[line[2].r][line[2].c];
      if (symbol == s1 && symbol == s2) {
        winningLines++;
        final lineMult = _symbolMultipliers[symbol];
        if (lineMult > totalMultiplier) totalMultiplier = lineMult;
        for (final p in line) {
          hitCells.add('${p.r}-${p.c}');
        }
      }
    }
    final win = (bet * totalMultiplier).round();
    return (win, totalMultiplier, hitCells, winningLines, false);
  }

  void _toggleAutoSpin() {
    setState(() => _autoSpin = !_autoSpin);
    if (_autoSpin && !_isSpinning) {
      unawaited(_startSpin());
    }
  }

  void _applyBetDelta(int delta, {bool haptic = true}) {
    if (_tutorialStateLoaded && _tutorialStep == 2 && delta > 0) {
      unawaited(_completeTutorialStepTwo());
    }
    if (_loadingBalance || _balance <= 0) return;
    final next = (_bet + delta).clamp(_minBet, _balance);
    if (next == _bet) return;
    setState(() => _bet = next);
    unawaited(BalanceService.setLastBet(_bet));
    unawaited(AnalyticsService.reportBetChange(_gameName, _bet));
    if (haptic) HapticFeedback.selectionClick();
  }

  static const _holdSteps = [50, 100, 500, 1000, 10000, 100000];
  static const _holdStepIntervalMs = 800;

  void _startContinuousBetAdjust(int delta) {
    _stopContinuousBetAdjust();
    _activeDelta = delta;
    _adjustWatch = Stopwatch()..start();
    _adjustTimer = Timer.periodic(const Duration(milliseconds: 40), (_) {
      final elapsed = _adjustWatch?.elapsedMilliseconds ?? 0;
      var factor = 3;
      if (elapsed >= 800 && elapsed < 2000) factor = 6;
      if (elapsed >= 2000) factor = 12;
      _applyBetDelta(_activeDelta * _betStep * factor, haptic: false);
    });
  }

  void _stopContinuousBetAdjust() {
    _adjustTimer?.cancel();
    _adjustTimer = null;
    _adjustWatch?.stop();
    _adjustWatch = null;
  }

  void _setMaxBet() {
    if (_tutorialStateLoaded && _tutorialStep == 2) {
      unawaited(_completeTutorialStepTwo());
    }
    if (_balance <= 0) return;
    if (_bet == _balance) return;
    setState(() => _bet = _balance);
    unawaited(BalanceService.setLastBet(_bet));
    unawaited(AnalyticsService.reportBetChange(_gameName, _bet));
    HapticFeedback.lightImpact();
  }

  void _openInfoDialog() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close info',
      barrierColor: const Color(0x80000000),
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, animation, secondaryAnimation) =>
          const InfoScreen(content: GoldVeinInfoContent()),
    );
  }

  Widget _buildOutlinedValue(String value, {double size = 18.58, double? letterSpacing}) {
    return Stack(
      children: [
        Text(
          value,
          textAlign: TextAlign.center,
          style: _valueTextStyle(
            size: size,
            letterSpacing: letterSpacing,
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = size * 0.046
              ..color = _balanceStroke,
          ),
        ),
        Text(
          value,
          textAlign: TextAlign.center,
          style: _valueTextStyle(size: size, letterSpacing: letterSpacing, color: _balanceFill),
        ),
      ],
    );
  }

  Widget _buildLastWinValue(String value, double scale) {
    final size = 21.34 * scale;
    return Stack(
      children: [
        Text(
          value,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Gotham',
            fontWeight: FontWeight.w900,
            fontStyle: FontStyle.normal,
            fontSize: size,
            height: 1.6,
            letterSpacing: -0.02 * size,
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.0
              ..color = const Color(0x40000000),
            shadows: const [
              Shadow(
                color: Color(0x40000000),
                offset: Offset(0, 2),
                blurRadius: 0,
              ),
            ],
          ),
        ),
        Text(
          value,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Gotham',
            fontWeight: FontWeight.w900,
            fontStyle: FontStyle.normal,
            fontSize: size,
            height: 1.6,
            letterSpacing: -0.02 * size,
            color: const Color(0xFFF3FF45),
            shadows: const [
              Shadow(
                color: Color(0x40000000),
                offset: Offset(0, 2),
                blurRadius: 0,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSymbolCell(
    int row,
    int col,
    double cellW,
    double cellH,
    double symbolW,
    double symbolH,
  ) {
    final symbol = _symbols[_matrix[row][col]];
    final currentSymbolKey = ValueKey('$symbol-$row-$col-${_reelTicks[col]}');
    final isHighlighted = _highlightedCells.contains('$row-$col');
    final bounce = _reelBounceControllers[col];
    final blurSigma = _reelSpinBlurSigma(col);
    return AnimatedBuilder(
      animation: bounce,
      builder: (context, child) {
        final bounceScale = 1 + Curves.easeOut.transform(bounce.value) * 0.08;
        final pulseScale = isHighlighted
            ? (1 + _winPulseController.value * 0.06)
            : 1.0;
        return Transform.scale(
          scale: bounceScale * pulseScale,
          child: SizedBox(
            width: cellW,
            height: cellH,
            child: Stack(
              alignment: Alignment.center,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 80),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  layoutBuilder: (currentChild, previousChildren) {
                    return currentChild ?? const SizedBox.shrink();
                  },
                  transitionBuilder: (child, animation) {
                    return SlideTransition(
                      position:
                          Tween<Offset>(
                            begin: const Offset(0, -0.08),
                            end: Offset.zero,
                          ).animate(
                            CurvedAnimation(
                              parent: animation,
                              curve: Curves.easeOutCubic,
                            ),
                          ),
                      child: child,
                    );
                  },
                  child: Transform.translate(
                    key: currentSymbolKey,
                    offset: Offset.zero,
                    child: ClipRect(
                      child: ImageFiltered(
                        imageFilter: ui.ImageFilter.blur(
                          sigmaX: 0,
                          sigmaY: blurSigma,
                        ),
                        child: Image.asset(
                          symbol,
                          fit: BoxFit.contain,
                          width: symbolW,
                          height: symbolH,
                          alignment: Alignment.center,
                          errorBuilder: (context, error, stackTrace) => Icon(
                            Icons.casino,
                            size: cellH * 0.42,
                            color: Colors.amber.shade700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (isHighlighted)
                  IgnorePointer(
                    child: Transform.translate(
                      offset: Offset.zero,
                      child: SizedBox(
                        width: cellW,
                        height: cellH,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: const Color(0xFFFFEA4C),
                              width: 2,
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
      },
    );
  }

  double _reelSpinBlurSigma(int col) {
    if (!_isSpinning) return 0;
    final progress = _reelProgress[col].clamp(0.0, 1.0);
    double intensity;
    if (progress <= 0.45) {
      // Softer start: blur grows more gradually so symbols remain visible.
      final t = (progress / 0.45).clamp(0.0, 1.0);
      intensity = Curves.easeInOutCubic.transform(t);
    } else {
      // Fade blur out smoothly toward the stop.
      final t = ((progress - 0.45) / 0.55).clamp(0.0, 1.0);
      intensity = 1 - Curves.easeInCubic.transform(t);
    }
    return (0.12 + intensity * 3.1).clamp(0.0, 3.4);
  }

  /// Slot machine content at design size (428x479). Used inside FittedBox for
  /// uniform scaling across resolutions.
  Widget _buildSlotMachineAtDesignSize() {
    const cellW = GoldVeinSlotZones.cellWidth;
    const cellH = GoldVeinSlotZones.cellHeight;
    const symbolW = _slotSymbolWidth;
    const symbolH = _slotSymbolHeight;

    return Stack(
      clipBehavior: Clip.hardEdge,
      children: [
        Image.asset(
          'assets/images/gold_vein/slots_back.png',
          width: GoldVeinSlotZones.viewWidth,
          height: GoldVeinSlotZones.viewHeight,
          fit: BoxFit.contain,
        ),
        ...List.generate(_rows, (r) {
          return List.generate(_cols, (c) {
            final centerX = GoldVeinSlotZones.colCenters[c] +
                GoldVeinSlotZones.symbolOffsetX +
                GoldVeinSlotZones.colOffsetX[c] +
                GoldVeinSlotZones.columnsShiftRight;
            final centerY = GoldVeinSlotZones.rowCenters[r] +
                GoldVeinSlotZones.symbolOffsetY;
            final left = centerX - cellW / 2;
            final top = centerY - cellH / 2;
            return Positioned(
              left: left,
              top: top,
              child: SizedBox(
                width: cellW,
                height: cellH,
                child: _buildSymbolCell(r, c, cellW, cellH, symbolW, symbolH),
              ),
            );
          });
        }).expand((e) => e),
      ],
    );
  }

  Widget _buildSlotMachine(double scale, double aspectRatio) {
    return SizedBox(
      width: _slotBoardWidth * scale,
      height: _slotBoardHeight * scale,
      child: FittedBox(
        fit: BoxFit.contain,
        alignment: Alignment.center,
        child: SizedBox(
          width: GoldVeinSlotZones.viewWidth,
          height: GoldVeinSlotZones.viewHeight,
          child: _buildSlotMachineAtDesignSize(),
        ),
      ),
    );
  }

  Widget _buildCenterMessage(BuildContext context, double scale) {
    if (!_showCenterMessage && !_isWinOverlayVisible) {
      return const SizedBox.shrink();
    }

    if (_isWinOverlayVisible) {
      final boardWidth = _slotBoardWidth * scale;
      final screenWidth = MediaQuery.sizeOf(context).width;
      final smallTitle = 33.8 * scale;
      final jackpotNumber = 51.52 * scale;
      final amountText = _formatWinAmount(_overlayAnimatedWin);

      Widget outlinedText(String text, double size, {double? stroke}) {
        final strokeWidth = stroke ?? (size * 0.046);
        final insetShadow = Shadow(
          color: const Color(0x40000000),
          offset: Offset(0, 4.83 * scale),
          blurRadius: 0,
        );
        return Stack(
          children: [
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Gotham',
                fontWeight: FontWeight.w900,
                fontSize: size,
                height: 1.6,
                letterSpacing: -0.02 * size,
                foreground: Paint()
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = strokeWidth
                  ..color = const Color(0x40000000),
                shadows: [insetShadow],
              ),
            ),
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Gotham',
                fontWeight: FontWeight.w900,
                fontSize: size,
                height: 1.6,
                letterSpacing: -0.02 * size,
                color: const Color(0xFFF3FF45),
                shadows: [insetShadow],
              ),
            ),
          ],
        );
      }

      final jackpotColumn = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: boardWidth,
            child: Center(
              child: outlinedText('JACKPOTS', smallTitle),
            ),
          ),
          SizedBox(height: 4 * scale),
          SizedBox(
            width: screenWidth,
            child: ClipRect(
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                child: Container(
                  width: screenWidth,
                  height: 88 * scale,
                  color: const Color(0x80F3FF45),
                  alignment: Alignment.center,
                  child: outlinedText(
                    amountText,
                    jackpotNumber,
                    stroke: 2.41 * scale,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(height: 4 * scale),
          SizedBox(
            width: boardWidth,
            child: Center(
              child: outlinedText('JACKPOTS', smallTitle),
            ),
          ),
        ],
      );

      return FadeTransition(
        opacity: CurvedAnimation(
          parent: _notificationController,
          curve: Curves.easeOut,
        ),
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.94, end: 1).animate(
            CurvedAnimation(
              parent: _notificationController,
              curve: Curves.easeOutCubic,
            ),
          ),
          child: _winBannerType == _WinBannerType.jackpots
              ? jackpotColumn
              : SizedBox(
                  width: boardWidth,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_winBannerType == _WinBannerType.win) ...[
                        outlinedText('WIN', smallTitle),
                        Transform.translate(
                          offset: Offset(0, -6 * scale),
                          child: outlinedText(amountText, smallTitle),
                        ),
                      ] else ...[
                        outlinedText(amountText, smallTitle),
                        Transform.translate(
                          offset: Offset(0, -6 * scale),
                          child: outlinedText('BIG WIN!', smallTitle),
                        ),
                      ],
                    ],
                  ),
                ),
        ),
      );
    }

    return FadeTransition(
      opacity: CurvedAnimation(
        parent: _notificationController,
        curve: Curves.easeOut,
      ),
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.86, end: 1).animate(
          CurvedAnimation(
            parent: _notificationController,
            curve: Curves.easeOutBack,
          ),
        ),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: 16 * scale,
            vertical: 10 * scale,
          ),
          decoration: BoxDecoration(
            color: _isCenterWin
                ? const Color(0xDD2E7D32)
                : const Color(0xDD6D1B1B),
            borderRadius: BorderRadius.circular(14 * scale),
            border: Border.all(color: Colors.white70, width: 1.2),
          ),
          child: Center(
            child: Text(
              _centerMessage,
              textAlign: TextAlign.center,
              style: GoogleFonts.montserrat(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 15 * scale,
            ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTutorialTapHint(double scale) {
    return AnimatedBuilder(
      animation: _tutorialTapController,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_tutorialTapController.value);
        final hintScale = 0.9 + (0.1 * t);
        return Transform.rotate(
          angle: -0.08,
          child: Transform.scale(
            scale: hintScale,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 80 * scale,
                  height: 60 * scale,
                  child: Image.asset(
                    'assets/images/common/arms_tap.png',
                    fit: BoxFit.contain,
                  ),
                ),
                SizedBox(height: 4 * scale),
                SizedBox(
                  width: 50 * scale,
                  height: 24 * scale,
                  child: Image.asset(
                    'assets/images/common/tap.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTutorialBetControls(double scale) {
    return SizedBox(
      width: 161 * scale,
      height: 96 * scale,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: 30 * scale,
            left: 0,
            right: 0,
            child: Container(
              width: 161 * scale,
              height: 57 * scale,
              decoration: BoxDecoration(
                color: const Color(0x66371810),
                borderRadius: BorderRadius.circular(20 * scale),
                border: Border.all(
                  color: const Color(0xFFFFEA4C),
                  width: 2 * scale,
                ),
              ),
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  Positioned(
                    left: -12 * scale,
                    child: PressableButton(
                      onTap: () => _applyBetDelta(-_betStep),
                      onLongPressStart: (_) => _startContinuousBetAdjust(-1),
                      onLongPressEnd: (_) => _stopContinuousBetAdjust(),
                      onLongPressCancel: _stopContinuousBetAdjust,
                      child: SizedBox(
                        width: 29 * scale,
                        height: 52 * scale,
                        child: Image.asset(
                          'assets/images/gold_vein/minus_btn.png',
                          fit: BoxFit.fill,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: -12 * scale,
                    child: PressableButton(
                      onTap: () => _applyBetDelta(_betStep),
                      onLongPressStart: (_) => _startContinuousBetAdjust(1),
                      onLongPressEnd: (_) => _stopContinuousBetAdjust(),
                      onLongPressCancel: _stopContinuousBetAdjust,
                      child: SizedBox(
                        width: 29 * scale,
                        height: 52 * scale,
                        child: Image.asset(
                          'assets/images/gold_vein/plus_btn.png',
                          fit: BoxFit.fill,
                        ),
                      ),
                    ),
                  ),
                  Center(
                    child: Transform.translate(
                      offset: const Offset(0, 2),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'YOUR BET:',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Gotham',
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 11.3 * scale,
                            height: 1.4,
                            letterSpacing: -0.02 * 11.3 * scale,
                          ),
                        ),
                        SizedBox(height: 2 * scale),
                        Transform.translate(
                          offset: const Offset(0, -5),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Transform.translate(
                                offset: const Offset(0, 2),
                                child: SizedBox(
                                  width: 22 * scale,
                                  height: 22 * scale,
                                  child: Image.asset(
                                    'assets/images/shop/coin_icon.png',
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),
                              SizedBox(width: 6 * scale),
                              _buildOutlinedValue(
                                _formatAmount(_bet),
                                size: (_bet > 999999 ? 19 : 20) * scale,
                                letterSpacing: -0.04 * (_bet > 999999 ? 19 : 20) * scale,
                              ),
                            ],
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
            top: 7 * scale,
            left: (161 - 132) / 2 * scale,
            child: PressableButton(
              onTap: _setMaxBet,
              child: SizedBox(
                width: 132 * scale,
                height: 29 * scale,
                child: Image.asset(
                  'assets/images/gold_vein/maxbet_btn.png',
                  fit: BoxFit.fill,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTutorialStepTwoOverlay(double scale) {
    return Positioned.fill(
      child: Stack(
        children: [
          const Positioned.fill(
            child: AbsorbPointer(
              absorbing: true,
              child: ColoredBox(color: _tutorialOverlayColor),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Center(
              child: Transform.translate(
                offset: Offset(60 * scale, 45 * scale),
                child: IgnorePointer(
                  child: SizedBox(
                    width: (_tutorialTrollSize + 90) * scale,
                    height: (_tutorialTrollSize + 90) * scale,
                    child: Image.asset(
                      'assets/images/tutorial/troll_education2.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 174 * scale - 40 * scale,
            child: Center(
              child: Transform.translate(
                offset: Offset(-60 * scale, 0),
                child: IgnorePointer(
                  child: SizedBox(
                    width: _tutorialBubbleWidth * scale,
                    height: _tutorialBubbleHeight * scale,
                    child: Image.asset(
                      'assets/images/tutorial/info.png',
                      fit: BoxFit.fill,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 37 * scale,
            bottom: 42 * scale,
            child: GestureDetector(
              onTap: () {
                if (_tutorialStateLoaded && _tutorialStep == 2) {
                  unawaited(_completeTutorialStepTwo());
                }
              },
              behavior: HitTestBehavior.opaque,
              child: _buildTutorialBetControls(scale),
            ),
          ),
          Positioned(
            left: 186 * scale - 20,
            bottom: -2 * scale,
            child: IgnorePointer(
              child: Transform.scale(
                scale: 0.85,
                child: _buildTutorialTapHint(scale),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onSpinTap() async {
    if (_tutorialStateLoaded && _tutorialStep == 3) {
      await _completeTutorialStepThree();
      if (!mounted) return;
    }
    if (_isSpinning) return;
    await _startSpin();
  }

  Widget _buildTutorialStepThreeOverlay(
    double scale,
    double maxWidth,
    double maxHeight,
  ) {
    final bubbleW = _tutorialBubbleStep3Width * scale;
    final bubbleH = _tutorialBubbleHeight * scale;
    final trollMaxW =
        (maxWidth * 0.92).clamp(200.0, 400.0) * _tutorialStep3TrollScale;
    final trollMaxH =
        (maxHeight * 0.34).clamp(160.0, 360.0) * _tutorialStep3TrollScale;
    final r = _tutorialStep3SpinRect;

    return Positioned.fill(
      child: Stack(
        key: _tutorialStep3OverlayKey,
        clipBehavior: Clip.none,
        children: [
          const Positioned.fill(
            child: AbsorbPointer(
              absorbing: true,
              child: ColoredBox(color: _tutorialOverlayColor),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Builder(
              builder: (ctx) {
                return MediaQuery.removePadding(
                  context: ctx,
                  removeBottom: true,
                  child: SafeArea(
                    top: false,
                    bottom: false,
                    left: true,
                    right: true,
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: max(8.0, 12 * scale),
                      ),
                      child: IgnorePointer(
                        child: Transform.translate(
                          offset: const Offset(-48, 30),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: trollMaxW,
                              maxHeight: trollMaxH,
                            ),
                            child: FittedBox(
                              fit: BoxFit.contain,
                              alignment: Alignment.bottomCenter,
                              child: SizedBox(
                                width: (_tutorialTrollSize + 60) *
                                    _tutorialStep3TrollScale,
                                height: (_tutorialTrollSize + 60) *
                                    _tutorialStep3TrollScale,
                                child: Image.asset(
                                  'assets/images/tutorial/troll_education3.png',
                                  fit: BoxFit.contain,
                                  alignment: Alignment.bottomCenter,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Positioned(
            left: r != null
                ? (r.center.dx - bubbleW / 2).clamp(
                    8.0,
                    maxWidth - bubbleW - 8,
                  )
                : ((maxWidth - bubbleW) / 2 + 30 * scale).clamp(
                    8.0,
                    maxWidth - bubbleW - 8,
                  ),
            top: r != null
                ? max(8.0, r.top - bubbleH - 12 * scale)
                : null,
            bottom: r == null ? 195 * scale : null,
            child: IgnorePointer(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: SizedBox(
                  width: bubbleW,
                  height: bubbleH,
                  child: Image.asset(
                    'assets/images/tutorial/info2.png',
                    fit: BoxFit.fill,
                  ),
                ),
              ),
            ),
          ),
          if (r != null)
            Positioned(
              left: r.left - 4,
              top: r.top - 4,
              width: r.width + 8,
              height: r.height + 8,
              child: AnimatedBuilder(
                animation: _tutorialTapController,
                builder: (context, child) {
                  final t = Curves.easeInOut.transform(
                    _tutorialTapController.value,
                  );
                  final pulseScale = 0.94 + (0.12 * t);
                  final radius = (11 * scale).clamp(9.0, 16.0);
                  return Transform.scale(
                    scale: pulseScale,
                    alignment: Alignment.center,
                    child: PressableButton(
                      onTap: _onSpinTap,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(radius),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xE0FFF145)
                                  .withValues(alpha: 0.82),
                              blurRadius: 12 + 8 * t,
                              spreadRadius: 2 + t,
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(radius),
                          child: SizedBox(
                            width: r.width,
                            height: r.height,
                            child: Image.asset(
                              'assets/images/gold_vein/spin_btn.png',
                              fit: BoxFit.fill,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1510),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final scale = min(
            constraints.maxWidth / 390,
            constraints.maxHeight / 844,
          ).clamp(0.82, 1.3);
          final aspectRatio = constraints.maxWidth / constraints.maxHeight;
          return Stack(
            children: [
              Positioned.fill(
                child: Image.asset(
                  'assets/images/gold_vein/bg3.png',
                  fit: BoxFit.cover,
                  alignment: Alignment.bottomCenter,
                ),
              ),
              SafeArea(
                child: SingleChildScrollView(
                  controller: _goldVeinScrollController,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: EdgeInsets.only(bottom: 16 * scale),
                  child: Column(
                    children: [
                      SizedBox(height: 200 * scale),
                      SizedBox(
                        width: double.infinity,
                        child: Center(
                          child: Transform.translate(
                            offset: Offset(0, -50 * scale),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                _buildSlotMachine(scale, aspectRatio),
                                if (!(_isWinOverlayVisible &&
                                    _winBannerType ==
                                        _WinBannerType.jackpots))
                                  _buildCenterMessage(context, scale),
                              ],
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 2 * scale),
                      Transform.translate(
                        offset: Offset(0, -105 * scale),
                        child: SizedBox(
                          width: 260 * scale,
                          height: 91 * scale,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Image.asset(
                                'assets/images/gold_vein/win_back.png',
                                fit: BoxFit.fill,
                                width: 260 * scale,
                                height: 91 * scale,
                              ),
                              Positioned(
                                top: 14 * scale,
                                child: Text(
                                  'YOU WIN:',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.montserrat(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 12.4 * scale,
                                  ),
                                ),
                              ),
                              Positioned(
                                bottom: 30 * scale,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Transform.translate(
                                      offset: const Offset(0, 2),
                                      child: SizedBox(
                                        width: 24 * scale,
                                        height: 24 * scale,
                                        child: Image.asset(
                                          'assets/images/shop/coin_icon.png',
                                          fit: BoxFit.contain,
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 6 * scale),
                                    _buildLastWinValue(
                                      _formatWinAmount(_lastWin),
                                      scale,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 5 * scale),
                      Transform.translate(
                        offset: Offset(0, -110 * scale),
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 18 * scale),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              (_tutorialStateLoaded && _tutorialStep == 2)
                                  ? SizedBox(
                                      width: 161 * scale,
                                      height: 96 * scale,
                                    )
                                  : SizedBox(
                                      width: 161 * scale,
                                      height: 96 * scale,
                                      child: Stack(
                                        clipBehavior: Clip.none,
                                        children: [
                                          Positioned(
                                            top: 30 * scale,
                                            left: 0,
                                            right: 0,
                                            child: Container(
                                              width: 161 * scale,
                                              height: 57 * scale,
                                              decoration: BoxDecoration(
                                                color: const Color(0x66371810),
                                                borderRadius:
                                                    BorderRadius.circular(
                                                      20 * scale,
                                                    ),
                                                border: Border.all(
                                                  color: const Color(
                                                    0xFFFFEA4C,
                                                  ),
                                                  width: 2 * scale,
                                                ),
                                              ),
                                              child: Stack(
                                                clipBehavior: Clip.none,
                                                alignment: Alignment.center,
                                                children: [
                                                  Positioned(
                                                    left: -12 * scale,
                                                    child: PressableButton(
                                                      onTap: () =>
                                                          _applyBetDelta(
                                                            -_betStep,
                                                          ),
                                                      onLongPressStart: (_) =>
                                                          _startContinuousBetAdjust(
                                                            -1,
                                                          ),
                                                      onLongPressEnd: (_) =>
                                                          _stopContinuousBetAdjust(),
                                                      onLongPressCancel:
                                                          _stopContinuousBetAdjust,
                                                      child: SizedBox(
                                                        width: 29 * scale,
                                                        height: 52 * scale,
                                                        child: Image.asset(
                                                          'assets/images/gold_vein/minus_btn.png',
                                                          fit: BoxFit.fill,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  Positioned(
                                                    right: -12 * scale,
                                                    child: PressableButton(
                                                      onTap: () =>
                                                          _applyBetDelta(
                                                            _betStep,
                                                          ),
                                                      onLongPressStart: (_) =>
                                                          _startContinuousBetAdjust(
                                                            1,
                                                          ),
                                                      onLongPressEnd: (_) =>
                                                          _stopContinuousBetAdjust(),
                                                      onLongPressCancel:
                                                          _stopContinuousBetAdjust,
                                                      child: SizedBox(
                                                        width: 29 * scale,
                                                        height: 52 * scale,
                                                        child: Image.asset(
                                                          'assets/images/gold_vein/plus_btn.png',
                                                          fit: BoxFit.fill,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  Center(
                                                    child: Transform.translate(
                                                      offset: const Offset(0, 2),
                                                      child: Column(
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .center,
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        children: [
                                                          Text(
                                                            'YOUR BET:',
                                                          textAlign:
                                                              TextAlign.center,
                                                          style: TextStyle(
                                                            fontFamily: 'Gotham',
                                                            color: Colors.white,
                                                            fontWeight:
                                                                FontWeight.w900,
                                                            fontSize:
                                                                11.3 * scale,
                                                            height: 1.4,
                                                            letterSpacing:
                                                                -0.02 * 11.3 * scale,
                                                          ),
                                                        ),
                                                        SizedBox(
                                                          height: 2 * scale,
                                                        ),
                                                        Transform.translate(
                                                          offset: const Offset(0, -5),
                                                          child: Row(
                                                            mainAxisSize:
                                                                MainAxisSize.min,
                                                            mainAxisAlignment:
                                                                MainAxisAlignment
                                                                    .center,
                                                            children: [
                                                              Transform.translate(
                                                                offset: const Offset(0, 2),
                                                                child: SizedBox(
                                                                  width: 22 *
                                                                      scale,
                                                                  height: 22 *
                                                                      scale,
                                                                  child: Image
                                                                      .asset(
                                                                    'assets/images/shop/coin_icon.png',
                                                                    fit: BoxFit
                                                                        .contain,
                                                                  ),
                                                                ),
                                                              ),
                                                              SizedBox(
                                                                  width:
                                                                      6 *
                                                                          scale),
                                                              _buildOutlinedValue(
                                                                _formatAmount(
                                                                    _bet),
                                                                size: (_bet > 999999 ? 19 : 20) *
                                                                    scale,
                                                                letterSpacing:
                                                                    -0.04 * (_bet > 999999 ? 19 : 20) * scale,
                                                              ),
                                                            ],
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
                                            top: 7 * scale,
                                            left: (161 - 132) / 2 * scale,
                                            child: PressableButton(
                                              onTap: _setMaxBet,
                                              child: SizedBox(
                                                width: 132 * scale,
                                                height: 29 * scale,
                                                child: Image.asset(
                                                  'assets/images/gold_vein/maxbet_btn.png',
                                                  fit: BoxFit.fill,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                              SizedBox(width: 44 * scale),
                              Transform.translate(
                                offset: Offset(0, 14 * scale),
                                child: Column(
                                  children: [
                                    Transform.translate(
                                      offset: Offset(0, 5 * scale),
                                      child: IgnorePointer(
                                        ignoring: _tutorialStateLoaded &&
                                            _tutorialStep == 3,
                                        child: PressableButton(
                                          onTap: _toggleAutoSpin,
                                          child: SizedBox(
                                            width: 69 * scale,
                                            height: 27 * scale,
                                            child: Opacity(
                                              opacity: _autoSpin ? 1 : 0.75,
                                              child: Image.asset(
                                                _autoSpin
                                                    ? 'assets/images/gold_vein/stop_btn.png'
                                                    : 'assets/images/gold_vein/auto_btn.png',
                                                fit: BoxFit.fill,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    SizedBox(height: 8 * scale),
                                    IgnorePointer(
                                      ignoring: _isSpinning ||
                                          (_tutorialStateLoaded &&
                                              _tutorialStep == 3),
                                      child:
                                          (_tutorialStateLoaded &&
                                                  _tutorialStep == 3)
                                              ? KeyedSubtree(
                                                  key: _tutorialStep3SpinKey,
                                                  child: PressableButton(
                                                    onTap: _onSpinTap,
                                                    child: SizedBox(
                                                      width: 103 * scale,
                                                      height: 58 * scale,
                                                      child: ColorFiltered(
                                                        colorFilter: _isSpinning
                                                            ? const ColorFilter.mode(
                                                                Color(0x99000000),
                                                                BlendMode.srcATop,
                                                              )
                                                            : const ColorFilter.mode(
                                                                Colors.transparent,
                                                                BlendMode.srcOver,
                                                              ),
                                                        child: Image.asset(
                                                          'assets/images/gold_vein/spin_btn.png',
                                                          fit: BoxFit.fill,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                )
                                              : PressableButton(
                                                  onTap: _onSpinTap,
                                                  child: SizedBox(
                                                    width: 103 * scale,
                                                    height: 58 * scale,
                                                    child: ColorFiltered(
                                                      colorFilter: _isSpinning
                                                          ? const ColorFilter.mode(
                                                              Color(0x99000000),
                                                              BlendMode.srcATop,
                                                            )
                                                          : const ColorFilter.mode(
                                                              Colors.transparent,
                                                              BlendMode.srcOver,
                                                            ),
                                                      child: Image.asset(
                                                        'assets/images/gold_vein/spin_btn.png',
                                                        fit: BoxFit.fill,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                    ),
                                  ],
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
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  bottom: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(height: 8 * scale),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12 * scale),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            PressableButton(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                Navigator.of(context).pop();
                              },
                              child: SizedBox(
                                width: 38 * scale,
                                height: 38 * scale,
                                child: Image.asset(
                                  'assets/images/gold_vein/back_btn.png',
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                            SizedBox(width: 42 * scale),
                            SizedBox(
                              width: 172 * scale,
                              height: 90 * scale,
                              child: MinersPassButton(
                                width: 172 * scale,
                                height: 90 * scale,
                                scale: scale,
                                source: 'gold_vein',
                              ),
                            ),
                            SizedBox(width: 42 * scale),
                            PressableButton(
                              onTap: _openInfoDialog,
                              child: SizedBox(
                                width: 38 * scale,
                                height: 38 * scale,
                                child: Image.asset(
                                  'assets/images/gold_vein/info_btn.png',
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 8 * scale),
                      Transform.translate(
                        offset: Offset(0, -6 * scale),
                        child: PressableButton(
                          onTap: _openShop,
                          child: SizedBox(
                            width: 242 * scale,
                            height: 85 * scale,
                            child: Stack(
                              clipBehavior: Clip.none,
                              alignment: Alignment.center,
                              children: [
                                Image.asset(
                                  'assets/images/gold_vein/coin_back2.png',
                                  fit: BoxFit.fill,
                                  width: 242 * scale,
                                  height: 85 * scale,
                                  errorBuilder: (context, error, stackTrace) =>
                                      Container(
                                        color: const Color(0x8850271C),
                                        width: 242 * scale,
                                        height: 85 * scale,
                                      ),
                                ),
                                Padding(
                                  padding: EdgeInsets.only(top: 5 * scale),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Transform.translate(
                                        offset: const Offset(0, 2),
                                        child: SizedBox(
                                          width: 22 * scale,
                                          height: 22 * scale,
                                          child: Image.asset(
                                            'assets/images/main_screen/coin_icon.png',
                                            fit: BoxFit.contain,
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: 6 * scale),
                                      _buildOutlinedValue(
                                        _loadingBalance
                                            ? '...'
                                            : _formatAmount(_displayBalance),
                                        size: 21.34 * scale,
                                      ),
                                    ],
                                  ),
                                ),
                                Positioned(
                                  bottom: -13 * scale,
                                  child: PressableButton(
                                    onTap: _openShop,
                                    child: SizedBox(
                                      width: 48 * scale,
                                      height: 48 * scale,
                                      child: Image.asset(
                                        'assets/images/main_screen/add_btn.png',
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 6 * scale),
                    ],
                  ),
                ),
              ),
              if (_tutorialStateLoaded && _tutorialStep == 2)
                _buildTutorialStepTwoOverlay(scale),
              if (_tutorialStateLoaded && _tutorialStep == 3)
                _buildTutorialStepThreeOverlay(
                  scale,
                  constraints.maxWidth,
                  constraints.maxHeight,
                ),
              if (_isWinOverlayVisible &&
                  _winBannerType == _WinBannerType.jackpots)
                Positioned.fill(
                  child: IgnorePointer(
                    child: FadeTransition(
                      opacity: CurvedAnimation(
                        parent: _notificationController,
                        curve: Curves.easeOut,
                      ),
                      child: Container(color: const Color(0x70000000)),
                    ),
                  ),
                ),
              if (_isWinOverlayVisible &&
                  _winBannerType == _WinBannerType.jackpots)
                Positioned.fill(
                  child: SafeArea(
                    child: IgnorePointer(
                      child: Center(
                        child: Transform.translate(
                          offset: Offset(0, -50 * scale),
                          child: _buildCenterMessage(context, scale),
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
