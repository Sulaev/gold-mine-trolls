import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gold_mine_trolls/screens/info_screen.dart';
import 'package:gold_mine_trolls/services/analytics_service.dart';
import 'package:gold_mine_trolls/services/audio_service.dart';
import 'package:gold_mine_trolls/screens/shop_screen.dart';
import 'package:gold_mine_trolls/services/balance_service.dart';
import 'package:gold_mine_trolls/widgets/pressable_button.dart';
import 'package:gold_mine_trolls/widgets/tap_banner.dart';

class MineDepthTowerScreen extends StatefulWidget {
  const MineDepthTowerScreen({super.key});

  @override
  State<MineDepthTowerScreen> createState() => _MineDepthTowerScreenState();
}

class _MineDepthTowerScreenState extends State<MineDepthTowerScreen>
    with TickerProviderStateMixin {
  static const _gameName = 'mine_depth_tower';
  static const _betStep = 50;
  static const _minBet = 50;
  static const _baseBet = 10000;
  static const _balanceStroke = Color(0x40000000);
  static const _balanceFill = Color(0xFFFFFFFF);
  static const _trollBaseY = -12.0;
  static const _trollStepY = 3.0;
  static const _multiplierTopInSafeArea = 141.0;

  final _rng = Random();
  final List<double> _multipliers = List.generate(17, (i) => 1.5 + i);
  late final AnimationController _breathController;
  late final AnimationController _shakeController;
  late final AnimationController _balanceCountController;

  int _balance = 0;
  int _displayBalance = 0;
  double _balanceAnimFrom = 0;
  int _bet = _baseBet;
  int _currentDepth = -1;
  int _potentialWin = 0;
  bool _loadingBalance = true;
  bool _inRun = false;
  bool _isGameOver = false;
  bool _isMoving = false;
  bool _isLoseReaction = false;
  bool _isLosing = false;
  bool _showLoseLight = false;
  double _loseLightOpacity = 0;
  static const _loseLightFadeDuration = Duration(milliseconds: 2200);
  Timer? _adjustTimer;
  Stopwatch? _adjustWatch;
  int _activeDelta = 0;

  @override
  void initState() {
    super.initState();
    unawaited(AnalyticsService.reportGameStart(_gameName));
    _breathController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1700),
    )..repeat(reverse: true);
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _precacheMineDepthAssets();
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
    _breathController.dispose();
    _shakeController.dispose();
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

  Future<void> _precacheMineDepthAssets() async {
    final assets = <String>[
      'assets/images/mine_depth_tower/bg_start.png',
      'assets/images/mine_depth_tower/standart.png',
      'assets/images/mine_depth_tower/troll_video.gif',
      'assets/images/mine_depth_tower/play_btn.png',
      'assets/images/mine_depth_tower/next_btn.png',
      'assets/images/mine_depth_tower/collect_btn.png',
      'assets/images/mine_depth_tower/game_over.png',
      'assets/images/mine_depth_tower/lose.png',
      'assets/images/mine_depth_tower/trayagain_btn.png',
      'assets/images/mine_depth_tower/light.png',
      'assets/images/gold_vein/back_btn.png',
      'assets/images/gold_vein/info_btn.png',
      'assets/images/gold_vein/minus_btn.png',
      'assets/images/gold_vein/plus_btn.png',
      'assets/images/gold_vein/coin_back2.png',
      'assets/images/shop/banner_miner_pass.png',
      'assets/images/shop/coin_icon.png',
      'assets/images/main_screen/coin_icon.png',
      'assets/images/main_screen/add_btn.png',
    ];
    for (final asset in assets) {
      await precacheImage(AssetImage(asset), context);
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
          const ShopScreen(source: 'mine_depth_tower'),
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

  Widget _buildOutlinedValue(String value, {double size = 18.58}) {
    TextStyle valueTextStyle({Color? color, Paint? foreground}) {
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

  void _applyBetDelta(int delta, {bool haptic = true}) {
    if (_loadingBalance ||
        _balance <= 0 ||
        _inRun ||
        _isGameOver ||
        _isLosing ||
        _isLoseReaction) {
      return;
    }
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

  Future<void> _startOrGoDeeper() async {
    if (_isMoving || _loadingBalance || _isLosing || _isLoseReaction) return;
    _shakeController.forward(from: 0);
    unawaited(AudioService.instance.playDrilling());
    if (!_inRun) {
      if (_bet <= 0 || _balance < _bet) return;
      setState(() {
        _balance -= _bet;
        _inRun = true;
        _isGameOver = false;
      });
      setState(() {
        _currentDepth = -1;
        _potentialWin = 0;
      });
      _animateBalanceChange(durationMs: 420);
      await BalanceService.setBalance(_balance);
    }
    await _goDeeperOneStep();
  }

  Future<void> _goDeeperOneStep() async {
    if (_currentDepth >= _multipliers.length - 1) return;
    setState(() => _isMoving = true);
    await Future.delayed(const Duration(milliseconds: 260));
    final success = _rng.nextBool();
    if (!mounted) return;
    if (success) {
      final nextDepth = _currentDepth + 1;
      final nextWin = (_bet * _multipliers[nextDepth]).round();
      setState(() {
        _currentDepth = nextDepth;
        _potentialWin = nextWin;
        _isMoving = false;
      });
      SystemSound.play(SystemSoundType.click);
    } else {
      unawaited(AnalyticsService.reportGameLoss(_gameName));
      setState(() {
        _inRun = false;
        _isLoseReaction = false;
        _isLosing = true;
        _isGameOver = false;
        _potentialWin = 0;
        _isMoving = false;
      });
      await Future.delayed(const Duration(milliseconds: 700));
      if (!mounted) return;
      setState(() {
        _showLoseLight = true;
        _loseLightOpacity = 0;
      });
      // Small buffer so the first light frame is committed before fade-in.
      await Future.delayed(const Duration(milliseconds: 120));
      if (!mounted) return;
      setState(() => _loseLightOpacity = 1);
      await Future.delayed(_loseLightFadeDuration);
      if (!mounted) return;
      setState(() {
        _isGameOver = true;
        _isLosing = false;
      });
      unawaited(AudioService.instance.playLose());
      await Future.delayed(const Duration(milliseconds: 16));
      if (!mounted) return;
      setState(() => _loseLightOpacity = 0);
      await Future.delayed(_loseLightFadeDuration);
      if (!mounted) return;
      setState(() {
        _showLoseLight = false;
        _loseLightOpacity = 0;
      });
    }
  }

  Future<void> _collectWin() async {
    if (!_inRun || _potentialWin <= 0 || _isMoving) return;
    unawaited(AnalyticsService.reportGameWin(_gameName));
    unawaited(AudioService.instance.playWin());
    final next = _balance + _potentialWin;
    setState(() {
      _balance = next;
      _inRun = false;
      _isGameOver = false;
      _currentDepth = -1;
      _potentialWin = 0;
    });
    _animateBalanceChange(durationMs: 760);
    await BalanceService.setBalance(next);
    HapticFeedback.lightImpact();
  }

  void _restartAfterLose() {
    if (!_isGameOver) return;
    setState(() {
      _isGameOver = false;
      _isLoseReaction = false;
      _isLosing = false;
    _showLoseLight = false;
      _loseLightOpacity = 0;
      _isMoving = false;
      _currentDepth = -1;
      _potentialWin = 0;
      _inRun = false;
    });
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
        '• Each deeper level gives bigger multiplier.\n'
        '• Chance to pass each level is 50/50.\n'
        '• Press PLAY/NEXT to go deeper.\n'
        '• Press COLLECT to secure current win.\n'
        '• If you hit lava, round is lost.',
      )),
    );
  }

  Widget _buildTopBar(double scale) {
    return Padding(
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

  Widget _buildMultiplierColumn(double scale) {
    final itemW = 57 * scale;
    final itemH = 32 * scale;
    final fontSize = 13.15 * scale;
    final strokeWidth = 0.62 * scale;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < _multipliers.length; i++)
          SizedBox(
            width: itemW,
            height: itemH,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Image.asset(
                  'assets/images/mine_depth_tower/standart.png',
                  fit: BoxFit.fill,
                ),
                Text(
                  'x${_multipliers[i].toStringAsFixed(1)}',
                  style: TextStyle(
                    fontFamily: 'Gotham',
                    fontWeight: FontWeight.w900,
                    fontSize: fontSize,
                    height: 1.6,
                    letterSpacing: -0.02 * fontSize,
                    foreground: Paint()
                      ..style = PaintingStyle.stroke
                      ..strokeWidth = strokeWidth
                      ..color = const Color(0x40000000),
                  ),
                ),
                Text(
                  'x${_multipliers[i].toStringAsFixed(1)}',
                  style: TextStyle(
                    fontFamily: 'Gotham',
                    fontWeight: FontWeight.w900,
                    fontSize: fontSize,
                    height: 1.6,
                    letterSpacing: -0.02 * fontSize,
                    color: const Color(0xFFF3FF45),
                    shadows: const [
                      Shadow(
                        color: Color(0x40000000),
                        offset: Offset(0, 1.23),
                        blurRadius: 0,
                      ),
                    ],
                  ),
                ),
                if (_currentDepth == i)
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6 * scale),
                      border: Border.all(
                        color: const Color(0xFFFFEA4C),
                        width: 1.2 * scale,
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildMultiplierOverlay(double scale) {
    return Positioned(
      right: 8 * scale,
      top: (_multiplierTopInSafeArea - 50) * scale,
      child: _buildMultiplierColumn(scale),
    );
  }

  Widget _buildTroll(double scale, double top) {
    return AnimatedPositioned(
      duration: _isLosing
          ? const Duration(milliseconds: 700)
          : const Duration(milliseconds: 260),
      curve: Curves.easeOut,
      top: _isLosing ? top + 900 * scale : top,
      left: 0,
      right: 0,
      child: Center(
        child: AnimatedBuilder(
          animation: Listenable.merge([_breathController, _shakeController]),
          builder: (context, child) {
            final t = Curves.easeInOut.transform(_breathController.value);
            final breathScale = 0.988 + (0.018 * t);
            final breathDy = -1.5 + (3.0 * t);
            final shakeProgress = _shakeController.value;
            final shakeAmplitude = (1 - shakeProgress) * 4.0;
            final shakeDx = sin(shakeProgress * pi * 8) * shakeAmplitude;
            return Transform.translate(
              offset: Offset(shakeDx * scale, breathDy * scale),
              child: Transform.scale(scale: breathScale, child: child),
            );
          },
          child: SizedBox(
            width: 220 * scale,
            height: 240 * scale,
            child: Image.asset(
              'assets/images/mine_depth_tower/troll.png',
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomControls(double scale) {
    if (_isLosing || _isLoseReaction) {
      return SizedBox(height: 111 * scale);
    }
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 18 * scale),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_inRun && !_isGameOver)
            Padding(
              padding: EdgeInsets.only(bottom: 8 * scale),
              child: Column(
                children: [
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
                        _formatAmount(_potentialWin),
                        size: 21.34 * scale,
                      ),
                    ],
                  ),
                  SizedBox(height: 8 * scale),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      PressableButton(
                        onTap: _collectWin,
                        child: SizedBox(
                          width: 161 * scale,
                          height: 49 * scale,
                          child: Image.asset(
                            'assets/images/mine_depth_tower/collect_btn.png',
                            fit: BoxFit.fill,
                          ),
                        ),
                      ),
                      SizedBox(width: 10 * scale),
                      PressableButton(
                        onTap: _startOrGoDeeper,
                        child: SizedBox(
                          width: 161 * scale,
                          height: 49 * scale,
                          child: Image.asset(
                            'assets/images/mine_depth_tower/next_btn.png',
                            fit: BoxFit.fill,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            )
          else
            Padding(
              padding: EdgeInsets.only(bottom: 8 * scale),
              child: PressableButton(
                onTap: _isGameOver ? _restartAfterLose : _startOrGoDeeper,
                child: SizedBox(
                  width: (_isGameOver ? 161 : 172) * scale,
                  height: (_isGameOver ? 49 : 40) * scale,
                  child: Image.asset(
                    _isGameOver
                        ? 'assets/images/mine_depth_tower/collect_btn.png'
                        : 'assets/images/mine_depth_tower/play_btn.png',
                    fit: BoxFit.fill,
                  ),
                ),
              ),
            ),
          if (!_inRun && !_isGameOver)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                PressableButton(
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
                SizedBox(width: 12 * scale),
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
                      size: 21.34 * scale,
                    ),
                  ],
                ),
                SizedBox(width: 12 * scale),
                PressableButton(
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
          final scale = min(
            constraints.maxWidth / 390,
            constraints.maxHeight / 844,
          ).clamp(0.82, 1.3);
          final visualDepth = max(0, _currentDepth + 1);
          final trollTop = max(
            0.0,
            (_trollBaseY + visualDepth * _trollStepY) * scale,
          );

          return Stack(
            children: [
              Positioned.fill(
                child: Image.asset(
                  'assets/images/mine_depth_tower/bg_start.png',
                  fit: BoxFit.cover,
                ),
              ),
              SafeArea(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Column(
                      children: [
                        SizedBox(height: 8 * scale),
                        _buildTopBar(scale),
                        SizedBox(height: 6 * scale),
                        _buildBalance(scale),
                        Expanded(
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              if (!_isGameOver) _buildTroll(scale, trollTop),
                            ],
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.only(bottom: 10 * scale),
                          child: _buildBottomControls(scale),
                        ),
                      ],
                    ),
                    _buildMultiplierOverlay(scale),
                  ],
                ),
              ),
              if (_isGameOver)
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _restartAfterLose,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.asset(
                          'assets/images/mine_depth_tower/game_over.png',
                          fit: BoxFit.cover,
                        ),
                        Center(
                          child: SizedBox(
                            width: 262 * scale,
                            height: 174 * scale,
                            child: Image.asset(
                              'assets/images/mine_depth_tower/lose.png',
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 34 * scale,
                          child: Center(
                            child: PressableButton(
                              onTap: _restartAfterLose,
                              child: SizedBox(
                                width: 205 * scale,
                                height: 45 * scale,
                                child: Image.asset(
                                  'assets/images/mine_depth_tower/trayagain_btn.png',
                                  fit: BoxFit.fill,
                                ),
                              ),
                            ),
                          ),
                        ),
                        SafeArea(
                          child: Column(
                            children: [
                              SizedBox(height: 8 * scale),
                              _buildTopBar(scale),
                              SizedBox(height: 6 * scale),
                              _buildBalance(scale),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (_showLoseLight)
                Positioned.fill(
                  child: IgnorePointer(
                    child: AnimatedOpacity(
                      opacity: _loseLightOpacity,
                      duration: _loseLightFadeDuration,
                      curve: Curves.easeInOutCubic,
                      child: Image.asset(
                        'assets/images/mine_depth_tower/light.png',
                        fit: BoxFit.cover,
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
