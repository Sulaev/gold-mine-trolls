import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gold_mine_trolls/screens/info_screen.dart';
import 'package:gold_mine_trolls/screens/shop_screen.dart';
import 'package:gold_mine_trolls/services/analytics_service.dart';
import 'package:gold_mine_trolls/services/audio_service.dart';
import 'package:gold_mine_trolls/services/balance_service.dart';
import 'package:gold_mine_trolls/widgets/pressable_button.dart';
import 'package:gold_mine_trolls/widgets/tap_banner.dart';

class ChiefTrollsWheelScreen extends StatefulWidget {
  const ChiefTrollsWheelScreen({super.key});

  @override
  State<ChiefTrollsWheelScreen> createState() => _ChiefTrollsWheelScreenState();
}

class _ChiefTrollsWheelScreenState extends State<ChiefTrollsWheelScreen>
    with TickerProviderStateMixin {
  static const _gameName = 'chief_trolls_wheel';
  static const _minBet = 50;
  static const _baseBet = 10000;
  static const _betStep = 50;
  static const _balanceStroke = Color(0x40000000);
  static const _balanceFill = Color(0xFFFFFFFF);

  int _balance = 0;
  int _displayBalance = 0;
  double _balanceAnimFrom = 0;
  int _bet = _baseBet;
  bool _loadingBalance = true;
  bool _isSpinning = false;
  double _wheelAngle = 0;
  int _lastWinAmount = 0;
  late final AnimationController _spinController;
  late final AnimationController _notificationController;
  late final AnimationController _winCountController;
  late final AnimationController _balanceCountController;
  late final math.Random _rng;
  Timer? _adjustTimer;
  Stopwatch? _adjustWatch;
  int _activeDelta = 0;
  bool _isWinOverlayVisible = false;
  int _overlayTargetWin = 0;
  int _overlayAnimatedWin = 0;
  // Clockwise zones starting from the sector near top-left.
  static const _zoneMultipliers = <double>[
    0,
    3,
    1,
    0,
    3,
    0,
    1,
    3,
    0,
    10,
    0,
    1,
    0,
  ];
  static const _firstZoneCenterDeg = 0.0;

  @override
  void initState() {
    super.initState();
    unawaited(AnalyticsService.reportGameStart(_gameName));
    _rng = math.Random();
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    );
    _notificationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _winCountController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 1800),
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
          final next = (_balanceAnimFrom + (_balance - _balanceAnimFrom) * t)
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
    _adjustTimer?.cancel();
    _adjustWatch?.stop();
    BalanceService.balanceNotifier.removeListener(_onBalanceNotifierChanged);
    _spinController.dispose();
    _notificationController.dispose();
    _winCountController.dispose();
    _balanceCountController.dispose();
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
          const ShopScreen(source: 'chief_trolls_wheel'),
    );
  }

  void _openInfoDialog() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close info',
      barrierColor: const Color(0x80000000),
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, animation, secondaryAnimation) =>
          InfoScreen(content: InfoScreen.placeholderContent(
        "Chief Troll's Wheel — screen skeleton is ready.\n"
        'Top HUD and bottom controls are connected.',
      )),
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

  Widget _buildOutlinedValue(String value, {double size = 18.58}) {
    TextStyle valueTextStyle({Color? color, Paint? foreground}) {
      return TextStyle(
        fontFamily: 'Gotham',
        color: foreground == null ? color : null,
        foreground: foreground,
        fontSize: size,
        fontWeight: FontWeight.w900,
        height: 1.6,
        letterSpacing: -0.02 * size,
        shadows: const [
          Shadow(color: _balanceStroke, offset: Offset(0, 1.74), blurRadius: 0),
        ],
      );
    }

    return Stack(
      children: [
        Text(
          value,
          style: valueTextStyle(
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = size * 0.046
              ..color = _balanceStroke,
          ),
        ),
        Text(value, style: valueTextStyle(color: _balanceFill)),
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

  void _applyBetDelta(int delta, {bool haptic = true}) {
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
    _adjustTimer?.cancel();
    _activeDelta = delta;
    _adjustWatch = Stopwatch()..start();
    _adjustTimer = Timer.periodic(const Duration(milliseconds: 120), (_) {
      final elapsed = _adjustWatch?.elapsedMilliseconds ?? 0;
      final level = (elapsed / _holdStepIntervalMs).floor().clamp(0, _holdSteps.length - 1);
      final step = _holdSteps[level];
      _applyBetDelta(_activeDelta * step, haptic: false);
    });
  }

  void _stopContinuousBetAdjust() {
    _adjustTimer?.cancel();
    _adjustTimer = null;
    _adjustWatch?.stop();
    _adjustWatch = null;
  }

  double _normalizeAngle(double angle) {
    final twoPi = 2 * math.pi;
    var result = angle % twoPi;
    if (result < 0) result += twoPi;
    return result;
  }

  double _zoneCenterAngle(int index) {
    final sector = (2 * math.pi) / _zoneMultipliers.length;
    return (_firstZoneCenterDeg * math.pi / 180) + index * sector;
  }

  double _pickWeightedMultiplier() {
    // Requested chances by weights: (x0 or x1)=70, x3=15, x10=5.
    final roll = _rng.nextDouble() * 90;
    if (roll < 70) {
      final low = _zoneMultipliers.where((m) => m == 0 || m == 1).toList();
      return low[_rng.nextInt(low.length)];
    }
    if (roll < 85) return 3;
    return 10;
  }

  int _pickIndexForMultiplier(double multiplier) {
    final matches = <int>[];
    for (var i = 0; i < _zoneMultipliers.length; i++) {
      if (_zoneMultipliers[i] == multiplier) {
        matches.add(i);
      }
    }
    return matches[_rng.nextInt(matches.length)];
  }

  Future<void> _spinTap() async {
    if (_isSpinning || _loadingBalance) return;
    if (_bet <= 0 || _balance < _bet) {
      HapticFeedback.heavyImpact();
      return;
    }
    HapticFeedback.lightImpact();
    final afterBet = _balance - _bet;
    setState(() => _balance = afterBet);
    _animateBalanceChange(durationMs: 420);
    await BalanceService.setBalance(afterBet);

    final targetMultiplier = _pickWeightedMultiplier();
    final targetIndex = _pickIndexForMultiplier(targetMultiplier);
    final desiredAngle = -_zoneCenterAngle(targetIndex);
    final currentNorm = _normalizeAngle(_wheelAngle);
    final desiredNorm = _normalizeAngle(desiredAngle);
    final delta = _normalizeAngle(desiredNorm - currentNorm);
    final spins = 4 + _rng.nextInt(3);
    final extraAngle = spins * (2 * math.pi) + delta;
    final begin = _wheelAngle;
    final end = _wheelAngle + extraAngle;
    final curve = CurvedAnimation(
      parent: _spinController,
      curve: Curves.easeOutCubic,
    );
    final tween = Tween<double>(begin: begin, end: end).animate(curve);

    setState(() => _isSpinning = true);
    unawaited(AudioService.instance.playChiefTrollsWheelSpin(2600));
    void listener() {
      if (!mounted) return;
      setState(() => _wheelAngle = tween.value);
    }

    _spinController
      ..stop()
      ..reset()
      ..addListener(listener);
    await _spinController.forward();
    _spinController.removeListener(listener);
    if (!mounted) return;
    final landedMultiplier = _zoneMultipliers[targetIndex];
    final winAmount = (_bet * landedMultiplier).round();
    final settledBalance = afterBet + winAmount;
    final exactAngle = _normalizeAngle(desiredAngle);
    setState(() {
      _isSpinning = false;
      _wheelAngle = exactAngle;
      _lastWinAmount = winAmount;
      _balance = settledBalance;
    });
    _animateBalanceChange(durationMs: 760);
    await BalanceService.setBalance(settledBalance);
    if (winAmount > 0) {
      unawaited(AnalyticsService.reportGameWin(_gameName));
      unawaited(AudioService.instance.playWin());
      if (landedMultiplier == 3 || landedMultiplier == 10) {
        _showWinOverlay(winAmount);
      }
    } else {
      unawaited(AnalyticsService.reportGameLoss(_gameName));
      unawaited(AudioService.instance.playLose());
    }
  }

  Widget _buildYouWinBanner(double scale) {
    return SizedBox(
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
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'Montserrat',
                fontWeight: FontWeight.w900,
                fontSize: 12.4 * scale,
              ),
            ),
          ),
          Positioned(
            bottom: 26 * scale,
            child: Row(
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
                _buildLastWinValue(_formatWinAmount(_lastWinAmount), scale),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showWinOverlay(int amount) {
    setState(() {
      _isWinOverlayVisible = true;
      _overlayTargetWin = amount;
      _overlayAnimatedWin = 0;
    });
    _notificationController.forward(from: 0);
    _winCountController.forward(from: 0);
  }

  void _dismissWinOverlay() {
    if (!_isWinOverlayVisible) return;
    _notificationController.reverse();
    setState(() => _isWinOverlayVisible = false);
  }

  Widget _buildWinOverlay(double scale) {
    final boardWidth = MediaQuery.of(context).size.width;
    final jackpotNumber = 51.52 * scale;
    final amountText = _formatWinAmount(_overlayAnimatedWin);
    final insetShadow = Shadow(
      color: const Color(0x40000000),
      offset: Offset(0, 4.83 * scale),
      blurRadius: 0,
    );

    Widget outlinedText(String text, double size, {double? stroke}) {
      final strokeWidth = stroke ?? (size * 0.046);
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
          child: ClipRect(
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
        ),
      ),
    );
  }

  Widget _buildTopBar(double scale) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 12 * scale),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
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
              bannerAsset: 'assets/images/shop/banner_miner_pass.png',
              width: 154 * scale,
              height: 80 * scale,
              tapScale: 0.62,
              tapOffset: const Offset(0, 59),
              onTap: () {},
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
    );
  }

  Widget _buildBalance(double scale) {
    return PressableButton(
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
                    _loadingBalance ? '...' : _formatAmount(_displayBalance),
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
    );
  }

  Widget _buildBottomControls(double scale) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 161 * scale,
          height: 58 * scale,
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
                      style: TextStyle(
                        color: Colors.white,
                        fontFamily: 'Montserrat',
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
        SizedBox(width: 44 * scale),
        PressableButton(
          onTap: _spinTap,
          child: SizedBox(
            width: 103 * scale,
            height: 58 * scale,
            child: ColorFiltered(
              colorFilter: _isSpinning
                  ? const ColorFilter.mode(Color(0x99000000), BlendMode.srcATop)
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
      ],
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
                  'assets/images/chief_trolls_wheel/bg.png',
                  fit: BoxFit.cover,
                ),
              ),
              SafeArea(
                child: Column(
                  children: [
                    SizedBox(height: 8 * scale),
                    _buildTopBar(scale),
                    SizedBox(height: 6 * scale),
                    _buildBalance(scale),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Transform.translate(
                            offset: Offset(0, 25 * scale),
                            child: Stack(
                              clipBehavior: Clip.none,
                              alignment: Alignment.center,
                              children: [
                                SizedBox(
                                  width: 376 * scale,
                                  height: 376 * scale,
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      SizedBox(
                                        width: 376 * scale,
                                        height: 376 * scale,
                                        child: Image.asset(
                                          'assets/images/chief_trolls_wheel/wheel_back.png',
                                          fit: BoxFit.contain,
                                        ),
                                      ),
                                      Transform.rotate(
                                        angle: _wheelAngle,
                                        child: SizedBox(
                                          width: 297 * scale,
                                          height: 297 * scale,
                                          child: Image.asset(
                                            'assets/images/chief_trolls_wheel/wheel.png',
                                            fit: BoxFit.contain,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Positioned(
                                  top: -60 * scale,
                                  child: SizedBox(
                                    width: 97 * scale,
                                    height: 97 * scale,
                                    child: Image.asset(
                                      'assets/images/chief_trolls_wheel/arrow.png',
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 14 * scale),
                          _buildYouWinBanner(scale),
                        ],
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.only(bottom: 12 * scale),
                      child: _buildBottomControls(scale),
                    ),
                  ],
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
                  child: IgnorePointer(
                    child: Center(child: _buildWinOverlay(scale)),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
