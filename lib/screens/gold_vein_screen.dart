import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gold_mine_trolls/screens/shop_screen.dart';
import 'package:gold_mine_trolls/services/audio_service.dart';
import 'package:gold_mine_trolls/services/balance_service.dart';
import 'package:gold_mine_trolls/screens/info_screen.dart';
import 'package:gold_mine_trolls/widgets/gold_vein_info_content.dart';
import 'package:gold_mine_trolls/widgets/pressable_button.dart';
import 'package:gold_mine_trolls/widgets/tap_banner.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum _WinBannerType { win, bigWin, jackpots }

class GoldVeinScreen extends StatefulWidget {
  const GoldVeinScreen({super.key});

  @override
  State<GoldVeinScreen> createState() => _GoldVeinScreenState();
}

class _GoldVeinScreenState extends State<GoldVeinScreen>
    with TickerProviderStateMixin {
  static const _rows = 5;
  static const _cols = 3;
  static const _betStep = 50;
  static const _minBet = 50;
  static const _baseBet = 10000;
  static const _balanceStroke = Color(0x40000000);
  static const _balanceFill = Color(0xFFFFFFFF);
  static const _slotBoardWidth = 428.0;
  static const _slotBoardHeight = 478.0;
  static const _slotRowGap = 6.0;
  static const _slotColGap = 20.0;
  static const _slotCellWidth = 78.0;
  static const _slotCellHeight = 70.0;
  static const _slotSymbolWidth = 75.0;
  static const _slotSymbolHeight = 60.0;
  static const _slotGridTop = 35.0;
  static const _slotGridOffsetX = -24.0;
  static const _slotGridOffsetY = 10.0;
  static const _tutorialOverlayColor = Color(0xB36D2E11);
  static const _tutorialBubbleWidth = 209.0;
  static const _tutorialBubbleHeight = 80.0;
  static const _tutorialBubbleStep3Width = 230.0;
  static const _tutorialTrollSize = 496.0;
  static const _tutorialStep1DoneKey = 'tutorial_step_1_done';
  static const _tutorialStep2DoneKey = 'tutorial_step_2_done';
  static const _tutorialStep3DoneKey = 'tutorial_step_3_done';

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
  int _lastWin = 100000;
  bool _isSpinning = false;
  bool _autoSpin = false;
  int _activeDelta = 0;
  bool _loadingBalance = true;
  int _tutorialStep = 0;
  bool _tutorialStateLoaded = false;

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

  // Higher weight -> more frequent symbol.
  final List<int> _symbolWeights = const [
    13,
    12,
    10,
    9,
    8,
    7,
    7,
    6,
    5,
    4,
    4,
    3,
  ];

  // Payout multipliers per payline (3 matching symbols) — matches info screen.
  final List<double> _symbolMultipliers = const [
    10.0,  // 1.1
    1.3,   // 1.2
    0.4,   // 1.3
    0.7,   // 1.4
    0.2,   // 1.5
    2.6,   // 1.6
    6.5,   // 1.7
    3.5,   // 1.8
    8.2,   // 1.9
    1.8,   // 1.10
    4.8,   // 1.11
    0.9,   // 1.12
  ];

  /// Jackpot: all 15 cells same symbol. Odds 1:1000.
  static const _jackpotOdds = 1000;

  /// Jackpot payout multiplier (bet × this).
  static const _jackpotMultiplier = 100.0;

  @override
  void initState() {
    super.initState();
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
    final savedBet = await BalanceService.getLastBet();
    var restoredBet = savedBet ?? _baseBet;
    if (value > 0) {
      restoredBet = restoredBet.clamp(_minBet, value);
    } else if (restoredBet < _minBet) {
      restoredBet = _minBet;
    }

    if (!mounted) return;
    setState(() {
      _balance = value;
      _displayBalance = value;
      _balanceAnimFrom = value.toDouble();
      _bet = restoredBet;
      _loadingBalance = false;
    });
    if (savedBet != restoredBet) {
      unawaited(BalanceService.setLastBet(restoredBet));
    }
  }

  Future<void> _loadTutorialState() async {
    final prefs = await SharedPreferences.getInstance();
    final step1Done = prefs.getBool(_tutorialStep1DoneKey) ?? false;
    final step2Done = prefs.getBool(_tutorialStep2DoneKey) ?? false;
    final step3Done = prefs.getBool(_tutorialStep3DoneKey) ?? false;
    if (!mounted) return;
    setState(() {
      if (!step1Done) {
        _tutorialStep = 0;
      } else if (!step2Done) {
        _tutorialStep = 2;
      } else if (!step3Done) {
        _tutorialStep = 3;
      } else {
        _tutorialStep = 0;
      }
      _tutorialStateLoaded = true;
    });
  }

  Future<void> _completeTutorialStepTwo() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_tutorialStep2DoneKey, true);
    if (!mounted) return;
    setState(() => _tutorialStep = 3);
  }

  Future<void> _completeTutorialStepThree() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_tutorialStep3DoneKey, true);
    if (!mounted) return;
    setState(() => _tutorialStep = 0);
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
          const ShopScreen(),
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
  }) {
    return TextStyle(
      fontFamily: 'Gotham',
      color: foreground == null ? color : null,
      foreground: foreground,
      fontSize: size,
      fontWeight: FontWeight.w900,
      fontStyle: FontStyle.normal,
      height: 1.6,
      letterSpacing: -0.02 * size,
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

    if (type != _WinBannerType.jackpots) {
      final hideMs = switch (type) {
        _WinBannerType.win => 900,
        _WinBannerType.bigWin => 1200,
        _WinBannerType.jackpots => 0,
      };
      _notificationHideTimer = Timer(Duration(milliseconds: hideMs), () {
        if (!mounted) return;
        _dismissWinOverlay();
      });
    }
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
      _showCenterResult('NOT ENOUGH GOLD', isWin: false);
      setState(() => _autoSpin = false);
      return;
    }

    final betToUse = _bet;
    final afterBetBalance = _balance - betToUse;
    setState(() {
      _isSpinning = true;
      _highlightedCells.clear();
      _balance = afterBetBalance;
    });
    _animateBalanceChange(durationMs: 420);
    await BalanceService.setBalance(_balance);

    final target = _generateSpinResult();

    unawaited(AudioService.instance.playRouletteSpin(2500));

    await Future.wait([
      _spinReel(0, target, 1050),
      _spinReel(1, target, 1600),
      _spinReel(2, target, 2250),
    ]);

    if (!mounted) return;
    final result = _calculateWin(target, betToUse);
    final win = result.$1;
    final totalMultiplier = result.$2;
    final winCells = result.$3;
    final winningLines = result.$4;
    final isJackpot = result.$5;

    setState(() {
      _highlightedCells
        ..clear()
        ..addAll(winCells);
      _lastWin = win;
      _isSpinning = false;
    });

    if (win > 0) {
      unawaited(AudioService.instance.playWin());
      _winPulseController.repeat(reverse: true);
      _balance += win;
      _animateBalanceChange(durationMs: 760);
      await BalanceService.setBalance(_balance);
      final isBigWin = totalMultiplier >= 5 || winningLines >= 3;
      _showWinOverlay(
        amount: win,
        type: isJackpot
            ? _WinBannerType.jackpots
            : (isBigWin ? _WinBannerType.bigWin : _WinBannerType.win),
      );
    } else {
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

  Future<void> _spinReel(
    int reel,
    List<List<int>> target,
    int durationMs,
  ) async {
    const minStepMs = 30;
    const maxStepMs = 165;

    final started = DateTime.now();
    while (true) {
      final elapsedMs = DateTime.now().difference(started).inMilliseconds;
      if (elapsedMs >= durationMs) break;
      if (!mounted) return;

      final progress = (elapsedMs / durationMs).clamp(0.0, 1.0);
      final eased = Curves.easeOutQuart.transform(progress);
      final stepMs = (minStepMs + (maxStepMs - minStepMs) * eased).round();

      setState(() {
        _shiftReelDown(reel, topSymbol: _weightedRandomSymbol());
        _reelTicks[reel]++;
      });
      await Future.delayed(Duration(milliseconds: stepMs));
    }

    // Deterministic landing: push exact target symbols from top so reel settles
    // without jitter or random flicker near the stop.
    for (var settleStep = 0; settleStep < _rows; settleStep++) {
      if (!mounted) return;
      setState(() {
        final topSymbol = target[_rows - 1 - settleStep][reel];
        _shiftReelDown(reel, topSymbol: topSymbol);
        _reelTicks[reel]++;
      });
      await Future.delayed(Duration(milliseconds: 72 + settleStep * 18));
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
    // Jackpot: 1 in 1000 — all cells same symbol.
    if (_rng.nextInt(_jackpotOdds) == 0) {
      final jackpotSymbol = _rng.nextInt(_symbols.length);
      return List.generate(
        _rows,
        (_) => List.generate(_cols, (_) => jackpotSymbol),
      );
    }

    final grid = List.generate(
      _rows,
      (_) => List.generate(_cols, (_) => _weightedRandomSymbol()),
    );
    // Occasional guaranteed line win (fruit-slot style) — ~15% to avoid too many dead spins.
    final shouldForceLineWin = _rng.nextDouble() < 0.15;
    if (shouldForceLineWin) {
      final line = _paylines[_rng.nextInt(_paylines.length)];
      final symbol = _weightedRandomSymbol();
      for (final p in line) {
        grid[p.r][p.c] = symbol;
      }
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

    // Regular paylines: each line pays independently (fruit-slot style).
    var totalMultiplier = 0.0;
    final hitCells = <String>{};
    var winningLines = 0;
    for (final line in _paylines) {
      final symbol = grid[line[0].r][line[0].c];
      final s1 = grid[line[1].r][line[1].c];
      final s2 = grid[line[2].r][line[2].c];
      if (symbol == s1 && symbol == s2) {
        winningLines++;
        totalMultiplier += _symbolMultipliers[symbol];
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
    if (_loadingBalance || _balance <= 0) return;
    final next = (_bet + delta).clamp(_minBet, _balance);
    if (next == _bet) return;
    setState(() => _bet = next);
    unawaited(BalanceService.setLastBet(_bet));
    if (_tutorialStateLoaded && _tutorialStep == 2) {
      unawaited(_completeTutorialStepTwo());
    }
    if (haptic) HapticFeedback.selectionClick();
  }

  void _startContinuousBetAdjust(int delta) {
    _stopContinuousBetAdjust();
    _activeDelta = delta;
    _adjustWatch = Stopwatch()..start();
    _adjustTimer = Timer.periodic(const Duration(milliseconds: 120), (_) {
      final elapsed = _adjustWatch?.elapsedMilliseconds ?? 0;
      var factor = 1;
      if (elapsed >= 3000 && elapsed < 5000) factor = 4;
      if (elapsed >= 5000) factor = 8;
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
    if (_balance <= 0) return;
    if (_bet == _balance) return;
    setState(() => _bet = _balance);
    unawaited(BalanceService.setLastBet(_bet));
    if (_tutorialStateLoaded && _tutorialStep == 2) {
      unawaited(_completeTutorialStepTwo());
    }
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

  Widget _buildOutlinedValue(String value, {double size = 18.58}) {
    return Stack(
      children: [
        Text(
          value,
          style: _valueTextStyle(
            size: size,
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = size * 0.046
              ..color = _balanceStroke,
          ),
        ),
        Text(
          value,
          style: _valueTextStyle(size: size, color: _balanceFill),
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
    final symbolOffset = _symbolPositionOffset(row, col);
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
                  duration: const Duration(milliseconds: 130),
                  switchInCurve: Curves.easeOutQuart,
                  switchOutCurve: Curves.easeInQuart,
                  layoutBuilder: (currentChild, previousChildren) {
                    // Keep only the active frame to avoid visible layering artifacts
                    // while we imitate reel masking.
                    return currentChild ?? const SizedBox.shrink();
                  },
                  transitionBuilder: (child, animation) {
                    final isIncoming = child.key == currentSymbolKey;
                    if (isIncoming) {
                      final inPosition =
                          Tween<Offset>(
                            begin: const Offset(0, -0.34),
                            end: Offset.zero,
                          ).animate(
                            CurvedAnimation(
                              parent: animation,
                              curve: Curves.easeOutQuart,
                            ),
                          );
                      return SlideTransition(
                        position: inPosition,
                        child: child,
                      );
                    }
                    // Outgoing frame stays hidden to prevent desync/overlay flicker.
                    return const SizedBox.shrink();
                  },
                  child: Transform.translate(
                    key: currentSymbolKey,
                    offset: symbolOffset,
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
                if (isHighlighted)
                  IgnorePointer(
                    child: Transform.translate(
                      offset: symbolOffset,
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

  Offset _symbolPositionOffset(int row, int col) {
    // Base per-column alignment.
    late final Offset base;
    if (col == 0) {
      base = const Offset(9, 5); // Left column.
    } else if (col == 1) {
      base = const Offset(4, 5); // Middle column.
    } else {
      base = const Offset(-2, 5); // Right column.
    }

    // Row compensation:
    // - top row -> push down by 10px
    // - bottom row -> pull up by 4px
    if (row == 0) return base + const Offset(0, 10);
    if (row == _rows - 1) return base + const Offset(0, -4);
    return base;
  }

  Widget _buildSlotMachine(double scale) {
    final boardW = _slotBoardWidth * scale;
    final boardH = _slotBoardHeight * scale;
    final gridTop = (_slotGridTop + _slotGridOffsetY) * scale;
    final colGap = _slotColGap * scale;
    final rowGap = _slotRowGap * scale;
    final cellW = _slotCellWidth * scale;
    final cellH = _slotCellHeight * scale;
    final gridW = _cols * cellW + (_cols - 1) * colGap;
    final gridH = _rows * cellH + (_rows - 1) * rowGap;
    final gridLeft = (boardW - gridW) / 2 + _slotGridOffsetX * scale;
    final symbolW = _slotSymbolWidth * scale;
    final symbolH = _slotSymbolHeight * scale;

    return SizedBox(
      width: boardW,
      height: boardH,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Image.asset(
            'assets/images/gold_vein/slots_back.png',
            width: boardW,
            height: boardH,
            fit: BoxFit.fill,
          ),
          Positioned(
            top: gridTop,
            left: gridLeft,
            child: SizedBox(
              width: gridW,
              height: gridH,
              child: Column(
                children: List.generate(_rows, (r) {
                  return Padding(
                    padding: EdgeInsets.only(
                      bottom: r == _rows - 1 ? 0 : rowGap,
                    ),
                    child: Row(
                      children: List.generate(_cols, (c) {
                        return Padding(
                          padding: EdgeInsets.only(
                            right: c == _cols - 1 ? 0 : colGap,
                          ),
                          child: _buildSymbolCell(
                            r,
                            c,
                            cellW,
                            cellH,
                            symbolW,
                            symbolH,
                          ),
                        );
                      }),
                    ),
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCenterMessage(double scale) {
    if (!_showCenterMessage && !_isWinOverlayVisible) {
      return const SizedBox.shrink();
    }

    if (_isWinOverlayVisible) {
      final boardWidth = _slotBoardWidth * scale;
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
          child: SizedBox(
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
                ] else if (_winBannerType == _WinBannerType.bigWin) ...[
                  outlinedText(amountText, smallTitle),
                  Transform.translate(
                    offset: Offset(0, -6 * scale),
                    child: outlinedText('BIG WIN!', smallTitle),
                  ),
                ] else ...[
                  outlinedText('JACKPOTS', smallTitle),
                  SizedBox(height: 4 * scale),
                  ClipRect(
                    child: BackdropFilter(
                      filter: ui.ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                      child: Container(
                        width: boardWidth,
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
                  SizedBox(height: 4 * scale),
                  outlinedText('JACKPOTS', smallTitle),
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
    );
  }

  Widget _buildTutorialTapHint(double scale) {
    return AnimatedBuilder(
      animation: _tutorialTapController,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_tutorialTapController.value);
        final hintScale = 0.9 + (0.2 * t);
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
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'YOUR BET:',
                        style: GoogleFonts.montserrat(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 10.5 * scale,
                        ),
                      ),
                      SizedBox(height: 2 * scale),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 24 * scale,
                            height: 24 * scale,
                            child: Image.asset(
                              'assets/images/shop/coin_icon.png',
                              fit: BoxFit.contain,
                            ),
                          ),
                          SizedBox(width: 6 * scale),
                          _buildOutlinedValue(
                            _formatAmount(_bet),
                            size: 19 * scale,
                          ),
                        ],
                      ),
                    ],
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
            right: -150 * scale,
            bottom: -56 * scale,
            child: IgnorePointer(
              child: SizedBox(
                width: _tutorialTrollSize * scale,
                height: _tutorialTrollSize * scale,
                child: Image.asset(
                  'assets/images/tutorial/troll_education2.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          Positioned(
            left: 32 * scale,
            bottom: 174 * scale,
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
          Positioned(
            left: 37 * scale,
            bottom: 42 * scale,
            child: _buildTutorialBetControls(scale),
          ),
          Positioned(
            left: 186 * scale,
            bottom: -2 * scale,
            child: IgnorePointer(child: _buildTutorialTapHint(scale)),
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
    await _startSpin();
  }

  Widget _buildTutorialStepThreeOverlay(double scale) {
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
            left: -128 * scale,
            bottom: -88 * scale,
            child: IgnorePointer(
              child: SizedBox(
                width: _tutorialTrollSize * scale,
                height: _tutorialTrollSize * scale,
                child: Image.asset(
                  'assets/images/tutorial/troll_education3.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          Positioned(
            left: 120 * scale,
            bottom: 126 * scale,
            child: IgnorePointer(
              child: SizedBox(
                width: _tutorialBubbleStep3Width * scale,
                height: _tutorialBubbleHeight * scale,
                child: Image.asset(
                  'assets/images/tutorial/info2.png',
                  fit: BoxFit.fill,
                ),
              ),
            ),
          ),
          Positioned(
            right: 28 * scale,
            bottom: 32 * scale,
            child: AnimatedBuilder(
              animation: _tutorialTapController,
              builder: (context, child) {
                final t = Curves.easeInOut.transform(
                  _tutorialTapController.value,
                );
                final pulseScale = 0.94 + (0.12 * t);
                return Transform.scale(
                  scale: pulseScale,
                  child: PressableButton(
                    onTap: _onSpinTap,
                    child: SizedBox(
                      width: 103 * scale,
                      height: 58 * scale,
                      child: Image.asset(
                        'assets/images/gold_vein/spin_btn.png',
                        fit: BoxFit.fill,
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
      body: LayoutBuilder(
        builder: (context, constraints) {
          final scale = min(
            constraints.maxWidth / 390,
            constraints.maxHeight / 844,
          ).clamp(0.82, 1.3);
          return Stack(
            children: [
              Positioned.fill(
                child: Image.asset(
                  'assets/images/gold_vein/bg3.png',
                  fit: BoxFit.cover,
                ),
              ),
              SafeArea(
                child: SingleChildScrollView(
                  physics: const NeverScrollableScrollPhysics(),
                  padding: EdgeInsets.only(bottom: 16 * scale),
                  child: Column(
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
                              width: 154 * scale,
                              height: 80 * scale,
                              child: TapBanner(
                                bannerAsset:
                                    'assets/images/shop/banner_miner_pass.png',
                                width: 154 * scale,
                                height: 80 * scale,
                                tapScale: 0.62,
                                tapOffset: const Offset(0, 59),
                                onTap: () {
                                  HapticFeedback.lightImpact();
                                },
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
                        offset: Offset(0, -10 * scale),
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
                                  padding: EdgeInsets.only(top: 2 * scale),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      SizedBox(
                                        width: 22 * scale,
                                        height: 22 * scale,
                                        child: Image.asset(
                                          'assets/images/main_screen/coin_icon.png',
                                          fit: BoxFit.contain,
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
                      Transform.translate(
                        offset: Offset(0, -50 * scale),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            _buildSlotMachine(scale),
                            if (!(_isWinOverlayVisible &&
                                _winBannerType == _WinBannerType.jackpots))
                              _buildCenterMessage(scale),
                          ],
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
                                  style: GoogleFonts.montserrat(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 12.4 * scale,
                                  ),
                                ),
                              ),
                              Positioned(
                                bottom: 26 * scale,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: 24 * scale,
                                      height: 24 * scale,
                                      child: Image.asset(
                                        'assets/images/shop/coin_icon.png',
                                        fit: BoxFit.contain,
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
                                                  Column(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .center,
                                                    children: [
                                                      Text(
                                                        'YOUR BET:',
                                                        style:
                                                            GoogleFonts.montserrat(
                                                              color:
                                                                  Colors.white,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w900,
                                                              fontSize:
                                                                  10.5 * scale,
                                                            ),
                                                      ),
                                                      SizedBox(
                                                        height: 2 * scale,
                                                      ),
                                                      Row(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        children: [
                                                          SizedBox(
                                                            width: 24 * scale,
                                                            height: 24 * scale,
                                                            child: Image.asset(
                                                              'assets/images/shop/coin_icon.png',
                                                              fit: BoxFit
                                                                  .contain,
                                                            ),
                                                          ),
                                                          SizedBox(
                                                            width: 6 * scale,
                                                          ),
                                                          _buildOutlinedValue(
                                                            _formatAmount(_bet),
                                                            size: 19 * scale,
                                                          ),
                                                        ],
                                                      ),
                                                    ],
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
                              (_tutorialStateLoaded && _tutorialStep == 3)
                                  ? SizedBox(
                                      width: 103 * scale,
                                      height: 93 * scale,
                                    )
                                  : Column(
                                      children: [
                                        Transform.translate(
                                          offset: Offset(0, 5 * scale),
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
                                        SizedBox(height: 8 * scale),
                                        IgnorePointer(
                                          ignoring: _isSpinning,
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
                                        ),
                                      ],
                                    ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_tutorialStateLoaded && _tutorialStep == 2)
                _buildTutorialStepTwoOverlay(scale),
              if (_tutorialStateLoaded && _tutorialStep == 3)
                _buildTutorialStepThreeOverlay(scale),
              if (_isWinOverlayVisible &&
                  _winBannerType == _WinBannerType.jackpots)
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _dismissWinOverlay,
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
                          child: _buildCenterMessage(scale),
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
