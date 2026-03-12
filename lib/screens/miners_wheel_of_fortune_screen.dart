import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gold_mine_trolls/screens/home_screen.dart';
import 'package:gold_mine_trolls/services/analytics_service.dart';
import 'package:gold_mine_trolls/services/audio_service.dart';
import 'package:gold_mine_trolls/screens/roulette_constants.dart';
import 'package:gold_mine_trolls/screens/shop_screen.dart';
import 'package:gold_mine_trolls/services/balance_service.dart';
import 'package:gold_mine_trolls/widgets/pressable_button.dart';
import 'package:gold_mine_trolls/widgets/warning_panel.dart';

class MinersWheelOfFortuneScreen extends StatefulWidget {
  const MinersWheelOfFortuneScreen({super.key});

  @override
  State<MinersWheelOfFortuneScreen> createState() =>
      _MinersWheelOfFortuneScreenState();
}

class _LeftSkewedHighlightPainter extends CustomPainter {
  const _LeftSkewedHighlightPainter(this.isHighlighted);

  final bool isHighlighted;

  @override
  void paint(Canvas canvas, Size size) {
    if (!isHighlighted) return;
    final skew = size.width * 0.24;
    final tipY = size.height * 0.5;
    final path = Path()
      ..moveTo(skew, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(skew, size.height)
      ..lineTo(0, tipY)
      ..close();

    final fill = Paint()..color = const Color(0x40FFEA4C);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = const Color(0xFFFFEA4C);
    canvas.drawPath(path, fill);
    canvas.drawPath(path, stroke);
  }

  @override
  bool shouldRepaint(covariant _LeftSkewedHighlightPainter oldDelegate) =>
      oldDelegate.isHighlighted != isHighlighted;
}

class _WinBannerBorderPainter extends CustomPainter {
  const _WinBannerBorderPainter({required this.radius});

  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );

    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0x80FFEA4C)
      ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 4);
    final border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0xFFFFEA4C);

    canvas.drawRRect(rrect, glow);
    canvas.drawRRect(rrect, border);
  }

  @override
  bool shouldRepaint(covariant _WinBannerBorderPainter oldDelegate) =>
      oldDelegate.radius != radius;
}

class _MinersWheelOfFortuneScreenState extends State<MinersWheelOfFortuneScreen>
    with TickerProviderStateMixin {
  static const _gameName = 'miners_wheel_of_fortune';
  static const _betStep = 50;
  static const _minBet = 50;
  static const _baseBet = 10000;
  static const _balanceStroke = Color(0x40000000);
  static const _balanceFill = Color(0xFFFFFFFF);
  static const _rouletteBackSize = 349.0;
  static const _rouletteSize = 250.0;
  static const _rouletteUpWidth = 145.0;
  static const _rouletteUpHeight = 139.0;
  static const _poleWidth = 327.0;
  static const _poleHeight = 178.0;
  static const _youWinBannerWidth = 243.0;
  static const _youWinBannerHeight = 36.0;
  static const _wheelZeroAngleOffset = -math.pi / 2;
  static const _ballLaneRadiusFactor = 0.336;
  static const _ballPocketAngleFineTune = 0.08;

  int _balance = 0;
  int _displayBalance = 0;
  double _balanceAnimFrom = 0;
  int _bet = _baseBet;
  int _lastWin = 0;
  bool _isSpinning = false;
  bool _autoSpin = false;
  int _activeDelta = 0;
  bool _loadingBalance = true;

  /// Selected zones for multi-bet mode
  final Set<RouletteBetKey> _selectedZones = {};

  Timer? _adjustTimer;
  Stopwatch? _adjustWatch;

  late final AnimationController _idleSpinController;
  late final AnimationController _spinController;
  late final AnimationController _notificationController;
  late final AnimationController _winCountController;
  late final AnimationController _balanceCountController;
  bool _idleAnimationEnabled = true;

  bool _wheelSpinActive = false;
  int? _currentWinningNumber;

  double _idleRouletteBase = 0;
  double _idleUpBase = 0;

  double _spinRouletteStart = 0;
  double _spinRouletteEnd = 0;
  double _spinUpStart = 0;
  double _spinUpEnd = 0;

  double _ballStartAngle = -math.pi / 2;
  double _ballEndAngle = -math.pi / 2;

  bool _isWinOverlayVisible = false;
  int _overlayTargetWin = 0;
  int _overlayAnimatedWin = 0;

  static const _europeanWheelOrder = [
    0,
    32,
    15,
    19,
    4,
    21,
    2,
    25,
    17,
    34,
    6,
    27,
    13,
    36,
    11,
    30,
    8,
    23,
    10,
    5,
    24,
    16,
    33,
    1,
    20,
    14,
    31,
    9,
    22,
    18,
    29,
    7,
    28,
    12,
    35,
    3,
    26,
  ];

  @override
  void initState() {
    super.initState();
    unawaited(AnalyticsService.reportGameStart(_gameName));
    _idleSpinController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 24),
    )..repeat();
    _spinController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 6400),
        )..addStatusListener((status) {
          if (status == AnimationStatus.completed) {
            _idleRouletteBase = _spinRouletteEnd;
            _idleUpBase = _spinUpEnd;
            _idleAnimationEnabled = false;
            _wheelSpinActive = false;
            _spinController.reset();
            unawaited(AudioService.instance.stopWheelSpin());
            if (mounted) setState(() {});
          }
        });
    _notificationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _winCountController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 2200),
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
    BalanceService.balanceNotifier.addListener(_onBalanceNotifierChanged);
    _loadBalance();
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
    _adjustWatch?.stop();
    _idleSpinController.dispose();
    _spinController.dispose();
    _notificationController.dispose();
    _winCountController.dispose();
    _balanceCountController.dispose();
    super.dispose();
  }

  Future<void> _loadBalance() async {
    final value = await BalanceService.getBalance();
    final savedBet = await BalanceService.getLastBet();
    final savedLastWin = await BalanceService.getMinersWheelLastWin();
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
      _lastWin = savedLastWin ?? 0;
      _loadingBalance = false;
    });
    if (savedBet != restoredBet) {
      unawaited(BalanceService.setLastBet(restoredBet));
    }
  }

  void _animateBalanceChange({int durationMs = 520}) {
    _balanceCountController.stop();
    _balanceAnimFrom = _displayBalance.toDouble();
    _balanceCountController.duration = Duration(milliseconds: durationMs);
    _balanceCountController.forward(from: 0);
  }

  void _openShop() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close shop',
      barrierColor: const Color(0x80000000),
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, animation, secondaryAnimation) =>
          const ShopScreen(source: 'miners_wheel_of_fortune'),
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

  void _goBackToHome() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }
    navigator.pushReplacement(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
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
      shadows: const [
        Shadow(color: _balanceStroke, offset: Offset(0, 1.74), blurRadius: 0),
      ],
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

  Widget _buildYouWinBanner(double scale) {
    final labelSize = 16.0 * scale;
    final amountSize = 21.34 * scale;
    final radius = 12.0 * scale;
    final labelStyle = TextStyle(
      fontFamily: 'Gotham',
      fontWeight: FontWeight.w900,
      fontStyle: FontStyle.normal,
      fontSize: labelSize,
      height: 1.6,
      letterSpacing: -0.02 * labelSize,
      color: const Color(0xFFFFFFFF),
      shadows: const [
        Shadow(
          color: Color(0x40000000),
          offset: Offset(0, 1.06),
          blurRadius: 0,
        ),
      ],
    );
    final amountStyle = TextStyle(
      fontFamily: 'Gotham',
      fontWeight: FontWeight.w900,
      fontStyle: FontStyle.normal,
      fontSize: amountSize,
      height: 1.6,
      letterSpacing: -0.02 * amountSize,
      color: const Color(0xFFF3FF45),
      shadows: const [
        Shadow(color: Color(0x40000000), offset: Offset(0, 2), blurRadius: 0),
      ],
    );

    return SizedBox(
      width: _youWinBannerWidth * scale,
      height: _youWinBannerHeight * scale,
      child: CustomPaint(
        painter: _WinBannerBorderPainter(radius: radius),
        child: Center(
          child: Transform.translate(
            offset: Offset(0, 2 * scale),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Transform.translate(
                  offset: Offset(0, -3 * scale),
                  child: Text('YOU WIN: ', style: labelStyle),
                ),
                Transform.translate(
                  offset: Offset(0, -3 * scale),
                  child: Text(
                    _formatWinAmount(_lastWin),
                    style: amountStyle,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showWinOverlay(int amount) {
    _notificationController.forward(from: 0);
    setState(() {
      _isWinOverlayVisible = true;
      _overlayTargetWin = amount;
      _overlayAnimatedWin = 0;
    });
    _winCountController.duration = const Duration(milliseconds: 2200);
    _winCountController.forward(from: 0);
  }

  void _dismissWinOverlay() {
    if (!_isWinOverlayVisible) return;
    _notificationController.reverse();
    setState(() => _isWinOverlayVisible = false);
  }

  Widget _buildJackpotOverlay(double scale) {
    if (!_isWinOverlayVisible || _currentWinningNumber == null) {
      return const SizedBox.shrink();
    }

    final titleSize = 33.8 * scale;
    final amountSize = 51.52 * scale;
    final amountText = _formatWinAmount(_overlayAnimatedWin);
    final titleText = _currentWinningNumber.toString();

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
          width: 428 * scale,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              outlinedText(titleText, titleSize),
              SizedBox(height: 4 * scale),
              ClipRect(
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                  child: Container(
                    width: 428 * scale,
                    height: 88 * scale,
                    color: const Color(0x80F3FF45),
                    alignment: Alignment.center,
                    child: outlinedText(
                      amountText,
                      amountSize,
                      stroke: 2.41 * scale,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 4 * scale),
              outlinedText(titleText, titleSize),
            ],
          ),
        ),
      ),
    );
  }

  void _applyBetDelta(int delta, {bool haptic = true}) {
    if (_loadingBalance || _balance <= 0) return;
    final next = (_bet + delta).clamp(_minBet, _balance);
    if (next == _bet) return;
    setState(() => _bet = next);
    unawaited(BalanceService.setLastBet(_bet));
    unawaited(AnalyticsService.reportBetChange(_gameName, _bet));
    if (haptic) HapticFeedback.selectionClick();
  }

  void _startContinuousBetAdjust(int delta) {
    _adjustTimer?.cancel();
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
    if (_balance <= 0) return;
    setState(() => _bet = _balance);
    unawaited(BalanceService.setLastBet(_bet));
    HapticFeedback.lightImpact();
  }

  void _toggleAutoSpin() {
    setState(() => _autoSpin = !_autoSpin);
    if (_autoSpin && !_isSpinning) {
      unawaited(_startSpin());
    }
  }

  double _currentRouletteAngle() {
    if (_wheelSpinActive) {
      final t = Curves.easeOutCubic.transform(_spinController.value);
      return _spinRouletteStart + (_spinRouletteEnd - _spinRouletteStart) * t;
    }
    if (!_idleAnimationEnabled) return _idleRouletteBase;
    final t = _idleSpinController.value;
    return _idleRouletteBase + (-2 * math.pi * 0.35) * t;
  }

  double _currentUpAngle() {
    if (_wheelSpinActive) {
      final t = Curves.easeOutCubic.transform(_spinController.value);
      return _spinUpStart + (_spinUpEnd - _spinUpStart) * t;
    }
    if (!_idleAnimationEnabled) return _idleUpBase;
    final t = _idleSpinController.value;
    return _idleUpBase + (-2 * math.pi * 0.45) * t;
  }

  double _targetBallPocketAngle(int winningNumber, double rouletteEndAngle) {
    final idx = _europeanWheelOrder.indexOf(winningNumber);
    final step = 2 * math.pi / _europeanWheelOrder.length;
    final pocketAngleInWheel = _wheelZeroAngleOffset + idx * step;
    return pocketAngleInWheel + rouletteEndAngle + _ballPocketAngleFineTune;
  }

  Future<void> _playSpinAnimation(int winningNumber) async {
    _currentWinningNumber = winningNumber;
    _spinRouletteStart = _currentRouletteAngle();
    _spinUpStart = _currentUpAngle();
    _ballStartAngle = -math.pi / 2;
    _idleAnimationEnabled = false;
    _wheelSpinActive = true;
    _spinController.reset();

    final randomJitter = (math.Random().nextDouble() - 0.5) * 0.25;
    _spinRouletteEnd = _spinRouletteStart - (2 * math.pi * 8.5) + randomJitter;
    _spinUpEnd = _spinUpStart - (2 * math.pi * 11.0) + randomJitter;
    _ballEndAngle = _targetBallPocketAngle(winningNumber, _spinRouletteEnd);

    if (mounted) setState(() {});
    unawaited(AudioService.instance.playWheelSpin(6400));
    await _spinController.forward();
  }

  Future<void> _startSpin() async {
    if (_isSpinning) return;
    if (_selectedZones.isEmpty) return;
    final totalBet = _bet * _selectedZones.length;
    if (_bet <= 0 || _balance < totalBet) {
      showWarningSnackBar(
        context,
        'Not enough coins to start the game.',
      );
      return;
    }

    final betToUse = _bet;
    final selectedSnapshot = Set<RouletteBetKey>.from(_selectedZones);
    final shouldAutoRepeat = _autoSpin;
    _notificationController.stop();
    setState(() {
      _isSpinning = true;
      _balance -= totalBet;
      _isWinOverlayVisible = false;
    });
    _animateBalanceChange(durationMs: 420);
    await BalanceService.setBalance(_balance);

    final rng = math.Random();
    final winningNumber = rng.nextInt(37);
    await _playSpinAnimation(winningNumber);

    if (!mounted) return;
    var totalWin = 0;
    for (final key in selectedSnapshot) {
      totalWin += calculateBetPayout(key, betToUse, winningNumber);
    }
    setState(() {
      _lastWin = totalWin;
      _isSpinning = false;
    });
    unawaited(BalanceService.setMinersWheelLastWin(totalWin));
    if (totalWin > 0) {
      unawaited(AnalyticsService.reportGameWin(_gameName));
      unawaited(AudioService.instance.playWin());
      setState(() => _balance += totalWin);
      _animateBalanceChange(durationMs: 760);
      await BalanceService.setBalance(_balance);
      if (!shouldAutoRepeat) {
        _showWinOverlay(totalWin);
      }
    } else {
      unawaited(AnalyticsService.reportGameLoss(_gameName));
      setState(() => _isWinOverlayVisible = false);
    }

    if (shouldAutoRepeat && mounted && !_isSpinning && !_isWinOverlayVisible) {
      await Future.delayed(const Duration(milliseconds: 350));
      if (mounted &&
          _autoSpin &&
          !_isWinOverlayVisible &&
          _selectedZones.isNotEmpty &&
          _balance >= (_bet * _selectedZones.length)) {
        unawaited(_startSpin());
      }
    }
  }

  Widget _buildTopBar(double scale) {
    final panelWidth = 242 * scale;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 12 * scale),
      child: SizedBox(
        height: 85 * scale,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Center(
              child: PressableButton(
                onTap: _openShop,
                child: SizedBox(
                  width: panelWidth,
                  height: 85 * scale,
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      Image.asset(
                        'assets/images/gold_vein/coin_back2.png',
                        fit: BoxFit.fill,
                        width: panelWidth,
                        height: 85 * scale,
                        errorBuilder: (context, error, stackTrace) =>
                            Container(
                              color: const Color(0x8850271C),
                              width: panelWidth,
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
            Positioned(
              left: 0,
              top: (85 - 48) / 2 * scale,
              child: PressableButton(
                onTap: () {
                  HapticFeedback.lightImpact();
                  _goBackToHome();
                },
                child: SizedBox(
                  width: 48 * scale,
                  height: 48 * scale,
                  child: Image.asset(
                    'assets/images/gold_vein/back_btn.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onBetZoneTap(RouletteBetZone zone) {
    if (_isSpinning) return;
    HapticFeedback.selectionClick();
    final key = RouletteBetKey(zone.type, zone.number);
    setState(() {
      if (_selectedZones.contains(key)) {
        _selectedZones.remove(key);
      } else {
        _selectedZones.add(key);
      }
    });
  }

  Widget _buildPoleWithOverlay(double scale) {
    final w = _poleWidth * scale;
    final h = _poleHeight * scale;
    final svgW = RoulettePoleZones.viewWidth;
    final svgH = RoulettePoleZones.viewHeight;
    final s = math.min(w / svgW, h / svgH);
    final renderW = svgW * s;
    final renderH = svgH * s;
    final offsetX = (w - renderW) / 2;
    final offsetY = (h - renderH) / 2;

    return SizedBox(
      width: w,
      height: h,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: SvgPicture.asset(
              'assets/images/miners_wheel_of_fortune/pole.svg',
              width: renderW,
              height: renderH,
              fit: BoxFit.contain,
            ),
          ),
          ...RoulettePoleZones.zones.map((zone) {
            final r = zone.rect;
            final rect = Rect.fromLTWH(
              offsetX + r.left * s,
              offsetY + r.top * s,
              r.width * s,
              r.height * s,
            );
            final isHighlighted = _selectedZones.any(
              (selection) => zoneMatchesSelection(zone, selection),
            );
            return Positioned(
              left: rect.left,
              top: rect.top,
              width: rect.width,
              height: rect.height,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _onBetZoneTap(zone),
                child: zone.type == RouletteBetType.zero
                    ? CustomPaint(
                        size: Size(rect.width, rect.height),
                        painter: _LeftSkewedHighlightPainter(isHighlighted),
                      )
                    : Container(
                        decoration: BoxDecoration(
                          color: isHighlighted
                              ? const Color(0x40FFEA4C)
                              : Colors.transparent,
                          border: isHighlighted
                              ? Border.all(
                                  color: const Color(0xFFFFEA4C),
                                  width: 2,
                                )
                              : null,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildWheelOfFortune(double scale) {
    final backSize = _rouletteBackSize * scale;
    final rouletteSize = _rouletteSize * scale;
    final upW = _rouletteUpWidth * scale;
    final upH = _rouletteUpHeight * scale;

    return AnimatedBuilder(
      animation: Listenable.merge([_idleSpinController, _spinController]),
      builder: (context, _) {
        final rouletteAngle = _currentRouletteAngle();
        final upAngle = _currentUpAngle();

        final spinT = _wheelSpinActive
            ? _spinController.value
            : (_currentWinningNumber != null ? 1.0 : 0.0);
        final ballTurns = 12.0;
        final orbitT = (spinT / 0.82).clamp(0.0, 1.0);
        final animatedBallAngle =
            _ballStartAngle +
            (_ballEndAngle + 2 * math.pi * ballTurns - _ballStartAngle) *
                Curves.easeOutCubic.transform(orbitT);
        final ballAngle = _wheelSpinActive
            ? animatedBallAngle
            : (_currentWinningNumber != null ? _ballEndAngle : -math.pi / 2);
        final dropT = ((spinT - 0.55) / 0.45).clamp(0.0, 1.0);
        final bounce = spinT > 0
            ? (1 - dropT) *
                  (math.sin(dropT * 32).abs() * (7 * scale) +
                      math.sin(dropT * 8).abs() * (2.2 * scale))
            : 0.0;
        final outerR = rouletteSize * 0.46;
        final laneR = rouletteSize * _ballLaneRadiusFactor;
        final ballRadius = _wheelSpinActive
            ? outerR -
                  (outerR - laneR) * Curves.easeOut.transform(dropT) +
                  bounce
            : (_currentWinningNumber != null ? laneR : outerR);
        final ballCenterOffset = Offset(
          math.cos(ballAngle) * ballRadius,
          math.sin(ballAngle) * ballRadius,
        );

        return SizedBox(
          width: backSize,
          height: backSize,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Image.asset(
                'assets/images/miners_wheel_of_fortune/roulette_back.png',
                width: backSize,
                height: backSize,
                fit: BoxFit.contain,
              ),
              Transform.rotate(
                angle: rouletteAngle,
                child: Image.asset(
                  'assets/images/miners_wheel_of_fortune/roulette.png',
                  width: rouletteSize,
                  height: rouletteSize,
                  fit: BoxFit.contain,
                ),
              ),
              Transform.rotate(
                angle: upAngle,
                child: Image.asset(
                  'assets/images/miners_wheel_of_fortune/roulette_up.png',
                  width: upW,
                  height: upH,
                  fit: BoxFit.contain,
                ),
              ),
              if (_wheelSpinActive || _currentWinningNumber != null)
                Transform.translate(
                  offset: ballCenterOffset,
                  child: Container(
                    width: 10 * scale,
                    height: 10 * scale,
                    decoration: const BoxDecoration(
                      color: Color(0xFFF6F6F6),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x99000000),
                          blurRadius: 3,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBottomBlock(double scale) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 18 * scale),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
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
                            onLongPressStart: (_) =>
                                _startContinuousBetAdjust(-1),
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
                            onLongPressStart: (_) =>
                                _startContinuousBetAdjust(1),
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
          ),
          SizedBox(width: 44 * scale),
          Column(
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
                ignoring: _isSpinning || _selectedZones.isEmpty,
                child: PressableButton(
                  onTap: _startSpin,
                  child: SizedBox(
                    width: 103 * scale,
                    height: 58 * scale,
                    child: ColorFiltered(
                      colorFilter: (_isSpinning || _selectedZones.isEmpty)
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final scale = (constraints.maxWidth / 390)
              .clamp(0.82, 1.3)
              .toDouble();
          return Stack(
            children: [
              Positioned.fill(
                child: Image.asset(
                  'assets/images/miners_wheel_of_fortune/bg.png',
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
                      _buildTopBar(scale),
                      SizedBox(height: 12 * scale),
                      _buildYouWinBanner(scale),
                      SizedBox(height: 8 * scale),
                      _buildWheelOfFortune(scale),
                      SizedBox(height: 8 * scale),
                      _buildPoleWithOverlay(scale),
                      SizedBox(height: 12 * scale),
                      _buildBottomBlock(scale),
                    ],
                  ),
                ),
              ),
              if (_isWinOverlayVisible)
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
              if (_isWinOverlayVisible)
                Positioned.fill(
                  child: SafeArea(
                    child: IgnorePointer(
                      child: Center(
                        child: Transform.translate(
                          offset: Offset(0, -20 * scale),
                          child: _buildJackpotOverlay(scale),
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
