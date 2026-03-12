import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:gold_mine_trolls/screens/miners_pass_screen.dart';
import 'package:gold_mine_trolls/screens/shop_screen.dart';
import 'package:gold_mine_trolls/services/analytics_service.dart';
import 'package:gold_mine_trolls/services/audio_service.dart';
import 'package:gold_mine_trolls/services/balance_service.dart';
import 'package:gold_mine_trolls/widgets/pressable_button.dart';
import 'package:gold_mine_trolls/widgets/tap_banner.dart';
import 'package:gold_mine_trolls/widgets/warning_panel.dart';

enum _CoeffMode { low, normal, high }

class GoldenAvalancheScreen extends StatefulWidget {
  const GoldenAvalancheScreen({super.key});

  @override
  State<GoldenAvalancheScreen> createState() => _GoldenAvalancheScreenState();
}

class _GoldenAvalancheScreenState extends State<GoldenAvalancheScreen>
    with TickerProviderStateMixin {
  static const _gameName = 'golden_avalanche';
  static const _betStep = 50;
  static const _minBet = 50;
  static const _baseBet = 10000;
  static const _balanceStroke = Color(0x40000000);
  static const _balanceFill = Color(0xFFFFFFFF);
  static const _pegSize = 14.0;
  static const _ballBackSize = 21.0;
  static const _ballSize = 13.0;
  static const _chestWidth = 38.0;
  static const _chestHeight = 35.0;
  static const _chestGap = 4.0;
  static const _pegRows = [3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13];

  static const _multipliersLow = [0.5, 1.0, 1.5, 2.0, 2.5, 2.0, 1.5, 1.0, 0.5];
  static const _multipliersNormal = [
    4.5,
    3.5,
    2.5,
    1.0,
    0.5,
    1.0,
    2.5,
    3.5,
    4.5,
  ];
  static const _multipliersHigh = [8.0, 6.0, 4.0, 2.0, 1.0, 2.0, 4.0, 6.0, 8.0];

  final _rng = Random();
  late final AnimationController _balanceCountController;

  int _balance = 0;
  int _displayBalance = 0;
  double _balanceAnimFrom = 0;
  int _bet = _baseBet;
  bool _loadingBalance = true;
  _CoeffMode _coeffMode = _CoeffMode.normal;
  int _ballSeq = 0;

  final List<_FallingBall> _balls = [];
  final Map<int, int> _chestWinOverlays = {};
  final Map<int, bool> _chestOpenState = {};
  double _plinkoScale = 1.0;
  Ticker? _physicsTicker;
  bool _autoDrop = false;
  Timer? _autoDropTimer;
  Timer? _adjustTimer;
  Stopwatch? _adjustWatch;
  final int _activeDelta = 0;

  Timer? _adjustTimer;
  Stopwatch? _adjustWatch;
  int _activeDelta = 0;

  @override
  void initState() {
    super.initState();
    unawaited(AnalyticsService.reportGameStart(_gameName));
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
    _autoDropTimer?.cancel();
    _adjustTimer?.cancel();
    _adjustWatch?.stop();
    _physicsTicker?.dispose();
    _balanceCountController.dispose();
    super.dispose();
  }

  List<double> get _multipliers {
    switch (_coeffMode) {
      case _CoeffMode.low:
        return _multipliersLow;
      case _CoeffMode.normal:
        return _multipliersNormal;
      case _CoeffMode.high:
        return _multipliersHigh;
    }
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
          const ShopScreen(source: 'golden_avalanche'),
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

  String _formatCompact(int value) {
    if (value >= 1000000)
      return '${(value / 1000000).toStringAsFixed(1).replaceAll('.0', '')}M';
    if (value >= 1000)
      return '${(value / 1000).toStringAsFixed(1).replaceAll('.0', '')}k';
    return value.toString();
  }

  Widget _buildOutlinedValue(String value, {double size = 18.58}) {
    return Stack(
      children: [
        Text(
          value,
          style: TextStyle(
            fontFamily: 'Gotham',
            fontWeight: FontWeight.w900,
            fontSize: size,
            height: 1.6,
            letterSpacing: -0.02 * size,
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = size * 0.046
              ..color = _balanceStroke,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontFamily: 'Gotham',
            fontWeight: FontWeight.w900,
            fontSize: size,
            height: 1.6,
            letterSpacing: -0.02 * size,
            color: _balanceFill,
          ),
        ),
      ],
    );
  }

  List<Offset> _getPegPositions(double scale) {
    const pegSize = _pegSize;
    const gap = 16.0;
    final s = pegSize * scale;
    final g = gap * scale;
    final boardWidth = (9 * _chestWidth + 8 * _chestGap) * scale;
    final boardCenterX = boardWidth / 2;
    final pegGridTop = _ballBackSize * scale + 8 * scale;

    final positions = <Offset>[];
    for (var r = 0; r < _pegRows.length; r++) {
      final n = _pegRows[r];
      final rowWidth = n * s + (n - 1) * g;
      final rowTop = pegGridTop + r * (s + g);
      for (var i = 0; i < n; i++) {
        final px = boardCenterX - rowWidth / 2 + s / 2 + i * (s + g);
        final py = rowTop + s / 2;
        positions.add(Offset(px, py));
      }
    }
    return positions;
  }

  void _runPhysicsStep(double scale) {
    const dt = 1 / 60.0;
    const gravity = 420.0;
    const bounceDamping = 0.65;
    const wallBounceDamping = 0.55;
    const ballRadius = _ballSize / 2;
    const pegRadius = _pegSize / 2;

    final s = pegRadius * scale;
    final ballR = ballRadius * scale;
    final pegPositions = _getPegPositions(scale);
    final boardWidth = (9 * _chestWidth + 8 * _chestGap) * scale;
    final boardCenterX = boardWidth / 2;
    final pegGridTop = _ballBackSize * scale + 8 * scale;
    final chestRowTop =
        pegGridTop +
        _pegRows.length * (_pegSize * scale + 16 * scale) +
        (12 - 20) * scale;
    final chestW = _chestWidth * scale;
    final chestGap = _chestGap * scale;
    final totalChestWidth = 9 * chestW + 8 * chestGap;

    for (final ball in _balls) {
      if (ball.chestIndex != null) continue;

      ball.vy += gravity * dt;
      ball.x += ball.vx * dt;
      ball.y += ball.vy * dt;

      // Keep balls inside board bounds so they never fly off-screen.
      final minX = ballR;
      final maxX = boardWidth - ballR;
      if (ball.x < minX) {
        ball.x = minX;
        if (ball.vx < 0) {
          ball.vx = -ball.vx * wallBounceDamping;
        }
      } else if (ball.x > maxX) {
        ball.x = maxX;
        if (ball.vx > 0) {
          ball.vx = -ball.vx * wallBounceDamping;
        }
      }

      for (var iter = 0; iter < 3; iter++) {
        for (final peg in pegPositions) {
          final dx = ball.x - peg.dx;
          final dy = ball.y - peg.dy;
          final dist = sqrt(dx * dx + dy * dy);
          final minDist = ballR + s;
          if (dist < minDist && dist > 0.001) {
            final nx = dx / dist;
            final ny = dy / dist;
            final overlap = minDist - dist;
            ball.x += nx * overlap;
            ball.y += ny * overlap;
            final vn = ball.vx * nx + ball.vy * ny;
            if (vn < 0) {
              ball.vx -= (1 + bounceDamping) * vn * nx;
              ball.vy -= (1 + bounceDamping) * vn * ny;
            }
          }
        }
      }

      if (ball.y + ballR > chestRowTop) {
        final chestRowLeft = boardCenterX - totalChestWidth / 2;
        final chestRowRight = boardCenterX + totalChestWidth / 2;
        final inBounds = ball.x >= chestRowLeft && ball.x <= chestRowRight;

        if (inBounds) {
          final relX = ball.x - chestRowLeft;
          var chestIndex = (relX / (chestW + chestGap)).floor();
          chestIndex = chestIndex.clamp(0, 8);
          final mult = _multipliers[chestIndex];
          final win = (_bet * mult).round();
          ball.chestIndex = chestIndex;
          ball.win = win;
          ball.y = chestRowTop - ballR;

          unawaited(AudioService.instance.playGoldenAvalancheCoin());
          if (win > 0) {
            unawaited(AnalyticsService.reportGameWin(_gameName));
          } else {
            unawaited(AnalyticsService.reportGameLoss(_gameName));
          }
          final newBalance = _balance + win;
          setState(() {
            _balance = newBalance;
            _chestOpenState[chestIndex] = true;
            _chestWinOverlays[chestIndex] = win;
          });
          Future.delayed(const Duration(seconds: 1), () {
            if (!mounted) return;
            setState(() => _chestWinOverlays.remove(chestIndex));
          });
          _animateBalanceChange(durationMs: 420);
          BalanceService.setBalance(newBalance);
        } else {
          unawaited(AnalyticsService.reportGameLoss(_gameName));
          ball.chestIndex = -1;
          ball.win = 0;
          ball.y = chestRowTop - ballR;
        }
      }
    }

    final hasActive = _balls.any((b) => b.chestIndex == null);
    if (!hasActive && _balls.isNotEmpty) {
      _physicsTicker?.stop();
      final landedBalls = _balls.where((b) => b.chestIndex != null).toList();
      final chestsToClear = landedBalls
          .where((b) => b.chestIndex! >= 0)
          .map((b) => b.chestIndex!)
          .toSet();
      Future.delayed(const Duration(milliseconds: 1200), () {
        if (!mounted) return;
        setState(() {
          for (final c in chestsToClear) {
            _chestOpenState[c] = false;
            _chestWinOverlays.remove(c);
          }
          for (final b in landedBalls) {
            _balls.remove(b);
          }
        });
      });
    }
  }

  void _startPhysicsTicker(double scale) {
    _physicsTicker?.dispose();
    _physicsTicker = createTicker((elapsed) {
      if (!mounted) return;
      _runPhysicsStep(scale);
      setState(() {});
    });
    _physicsTicker!.start();
  }

  Future<void> _onDrop() async {
    if (_loadingBalance || _balance < _bet) {
      if (!_loadingBalance) {
        showWarningSnackBar(context, 'Not enough coins to start the game.');
      }
      return;
    }
    HapticFeedback.lightImpact();

    final newBalance = _balance - _bet;
    setState(() => _balance = newBalance);
    _animateBalanceChange(durationMs: 420);
    await BalanceService.setBalance(newBalance);

    final boardWidth = (9 * _chestWidth + 8 * _chestGap) * _plinkoScale;
    final boardCenterX = boardWidth / 2;
    final startY = _ballBackSize * _plinkoScale / 2;
    final startX = boardCenterX + (_rng.nextDouble() - 0.5) * 4;

    final ball = _FallingBall(
      id: _ballSeq++,
      x: startX,
      y: startY,
      vx: (_rng.nextDouble() - 0.5) * 20,
      vy: 0,
    );
    setState(() => _balls.add(ball));

    _startPhysicsTicker(_plinkoScale);
  }

  Future<void> _applyBetDelta(int delta, {bool haptic = true}) async {
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
      unawaited(
        _applyBetDelta(_activeDelta * _betStep * factor, haptic: false),
      );
    });
  }

  void _stopContinuousBetAdjust() {
    _adjustTimer?.cancel();
    _adjustTimer = null;
    _adjustWatch?.stop();
    _adjustWatch = null;
  }

  void _setMaxBet() {
    if (_loadingBalance || _balance <= 0) return;
    if (_bet == _balance) return;
    setState(() => _bet = _balance);
    unawaited(BalanceService.setLastBet(_bet));
    unawaited(AnalyticsService.reportBetChange(_gameName, _bet));
    HapticFeedback.lightImpact();
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
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        const MinersPassScreen(source: 'golden_avalanche'),
                  ),
                );
              },
            ),
          ),
          SizedBox(width: 42 * scale),
          SizedBox(width: 38 * scale, height: 38 * scale),
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

  bool get _hasFallingBalls => _balls.any((b) => b.chestIndex == null);

  Widget _buildCoeffButtons(double scale) {
    final disabled = _hasFallingBalls;
    Widget btn(_CoeffMode mode, String activeAsset, String passiveAsset) {
      final isActive = _coeffMode == mode;
      return Opacity(
        opacity: disabled ? 0.5 : 1,
        child: PressableButton(
          onTap: disabled
              ? null
              : () {
                  if (_coeffMode == mode) return;
                  setState(() => _coeffMode = mode);
                  HapticFeedback.selectionClick();
                },
          child: SizedBox(
            width: 101 * scale,
            height: 33 * scale,
            child: Image.asset(
              isActive ? activeAsset : passiveAsset,
              fit: BoxFit.fill,
            ),
          ),
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        btn(
          _CoeffMode.low,
          'assets/images/golden_avalanche/low_btn.png',
          'assets/images/golden_avalanche/low_btn_passive.png',
        ),
        SizedBox(width: 8 * scale),
        btn(
          _CoeffMode.normal,
          'assets/images/golden_avalanche/normal_btn.png',
          'assets/images/golden_avalanche/normal_btn_passive.png',
        ),
        SizedBox(width: 8 * scale),
        btn(
          _CoeffMode.high,
          'assets/images/golden_avalanche/high_btn.png',
          'assets/images/golden_avalanche/high_btn_passive.png',
        ),
      ],
    );
  }

  Widget _buildBottomControls(double scale) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
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
                Positioned(
                  top: -24 * scale,
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
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PressableButton(
              onTap: _toggleAutoDrop,
              child: Opacity(
                opacity: _autoDrop ? 1 : 0.75,
                child: SizedBox(
                  width: 69 * scale,
                  height: 27 * scale,
                  child: Image.asset(
                    'assets/images/gold_vein/auto_btn.png',
                    fit: BoxFit.fill,
                  ),
                ),
              ),
            ),
            SizedBox(height: 4 * scale),
            PressableButton(
              onTap: _onDrop,
              child: SizedBox(
                width: 103 * scale,
                height: 58 * scale,
                child: Image.asset(
                  'assets/images/golden_avalanche/drop_btn.png',
                  fit: BoxFit.fill,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _toggleAutoDrop() {
    setState(() => _autoDrop = !_autoDrop);
    _autoDropTimer?.cancel();
    if (_autoDrop) {
      _scheduleAutoDrop();
    }
  }

  void _scheduleAutoDrop() {
    _autoDropTimer?.cancel();
    if (!_autoDrop || !mounted) return;
    _autoDropTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted || !_autoDrop) return;
      if (_balance >= _bet) {
        _onDrop();
      } else {
        setState(() => _autoDrop = false);
      }
      if (_autoDrop) _scheduleAutoDrop();
    });
  }

  Widget _buildPegGrid(double scale) {
    const pegSize = _pegSize;
    const gap = 16.0;
    final s = pegSize * scale;
    final g = gap * scale;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final n in _pegRows)
          Padding(
            padding: EdgeInsets.only(bottom: g),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < n; i++) ...[
                  if (i > 0) SizedBox(width: g),
                  SizedBox(
                    width: s,
                    height: s,
                    child: Image.asset(
                      'assets/images/golden_avalanche/point.png',
                      fit: BoxFit.fill,
                    ),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildFallingBalls(double scale) {
    final boardWidth = (9 * _chestWidth + 8 * _chestGap) * scale;
    final ballSize = _ballSize * scale;
    return IgnorePointer(
      child: SizedBox(
        width: boardWidth,
        height: 260 * scale,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            for (final ball in _balls)
              if (ball.chestIndex == null)
                Positioned(
                  key: ValueKey('fall_${ball.id}'),
                  left: ball.x - ballSize / 2,
                  top: ball.y - ballSize / 2,
                  child: SizedBox(
                    width: ballSize,
                    height: ballSize,
                    child: Image.asset(
                      'assets/images/golden_avalanche/ball.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlinkoField(double scale) {
    final boardWidth = (9 * _chestWidth + 8 * _chestGap) * scale;
    return SizedBox(
      width: boardWidth,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: _ballBackSize * scale,
                      height: _ballBackSize * scale,
                      child: Image.asset(
                        'assets/images/golden_avalanche/ball_back.png',
                        fit: BoxFit.fill,
                      ),
                    ),
                    Transform.translate(
                      offset: const Offset(-1, 0),
                      child: SizedBox(
                        width: _ballSize * scale,
                        height: _ballSize * scale,
                        child: Image.asset(
                          'assets/images/golden_avalanche/ball.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 8 * scale),
              _buildPegGrid(scale),
              SizedBox(height: 12 * scale),
              Transform.translate(
                offset: Offset(0, -20 * scale),
                child: _buildChestRow(scale),
              ),
            ],
          ),
          _buildFallingBalls(scale),
        ],
      ),
    );
  }

  Widget _buildMultiplierText(double mult, double scale) {
    return Stack(
      children: [
        Text(
          'x${mult.toStringAsFixed(mult == mult.roundToDouble() ? 0 : 1)}',
          style: TextStyle(
            fontFamily: 'Gotham',
            fontWeight: FontWeight.w900,
            fontSize: 9.85 * scale,
            height: 1.6,
            letterSpacing: -0.04 * 9.85 * scale,
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 0.59 * scale
              ..color = const Color(0x66AC3A17),
          ),
        ),
        Text(
          'x${mult.toStringAsFixed(mult == mult.roundToDouble() ? 0 : 1)}',
          style: TextStyle(
            fontFamily: 'Gotham',
            fontWeight: FontWeight.w900,
            fontSize: 9.85 * scale,
            height: 1.6,
            letterSpacing: -0.04 * 9.85 * scale,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildChestRow(double scale) {
    const chestW = _chestWidth;
    const chestH = _chestHeight;
    const gap = _chestGap;
    final totalW = 9 * chestW + 8 * gap;
    return SizedBox(
      width: totalW * scale,
      height: (chestH + 24) * scale,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(9, (i) {
          final mult = _multipliers[i];
          final win = _chestWinOverlays[i];
          return Padding(
            padding: EdgeInsets.only(right: i < 8 ? gap * scale : 0),
            child: SizedBox(
              width: chestW * scale,
              height: (chestH + 24) * scale,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.topCenter,
                children: [
                  if (win != null)
                    TweenAnimationBuilder<double>(
                      key: ValueKey('bounce_$i _$win'),
                      tween: Tween(begin: 0, end: 1),
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOut,
                      builder: (_, t, _) {
                        final dy = sin(t * pi) * 6 * scale;
                        return Transform.translate(
                          offset: Offset(0, dy),
                          child: SizedBox(
                            width: chestW * scale,
                            height: chestH * scale,
                            child: Image.asset(
                              'assets/images/golden_avalanche/chest.png',
                              fit: BoxFit.fill,
                            ),
                          ),
                        );
                      },
                    )
                  else
                    SizedBox(
                      width: chestW * scale,
                      height: chestH * scale,
                      child: Image.asset(
                        'assets/images/golden_avalanche/chest.png',
                        fit: BoxFit.fill,
                      ),
                    ),
                  Positioned(
                    bottom: 18 * scale,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: win != null
                          ? TweenAnimationBuilder<double>(
                              key: ValueKey('bounce_txt_$i _$win'),
                              tween: Tween(begin: 0, end: 1),
                              duration: const Duration(milliseconds: 180),
                              curve: Curves.easeOut,
                              builder: (_, t, _) {
                                final dy = sin(t * pi) * 6 * scale;
                                return Transform.translate(
                                  offset: Offset(0, dy),
                                  child: _buildMultiplierText(mult, scale),
                                );
                              },
                            )
                          : _buildMultiplierText(mult, scale),
                    ),
                  ),
                  if (win != null)
                    TweenAnimationBuilder<double>(
                      key: ValueKey('fly_$i _$win'),
                      tween: Tween(begin: 0, end: 1),
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeOut,
                      builder: (_, t, _) {
                        final y =
                            chestH * scale / 2 + 20 * scale - 60 * t * scale;
                        return Positioned(
                          left: 0,
                          right: 0,
                          top: y,
                          child: Center(
                            child: Stack(
                              children: [
                                Text(
                                  _formatCompact(win),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                  style: TextStyle(
                                    fontFamily: 'Gotham',
                                    fontWeight: FontWeight.w900,
                                    fontSize: 10 * scale,
                                    height: 1.6,
                                    letterSpacing: -0.02 * 10 * scale,
                                    foreground: Paint()
                                      ..style = PaintingStyle.stroke
                                      ..strokeWidth = 1.8 * scale
                                      ..color = const Color(0xFF2A1810),
                                  ),
                                ),
                                Text(
                                  _formatCompact(win),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                  style: TextStyle(
                                    fontFamily: 'Gotham',
                                    fontWeight: FontWeight.w900,
                                    fontSize: 10 * scale,
                                    height: 1.6,
                                    letterSpacing: -0.02 * 10 * scale,
                                    color: const Color(0xFFF3FF45),
                                    shadows: const [
                                      Shadow(
                                        color: Color(0x40000000),
                                        offset: Offset(0, 1.35),
                                        blurRadius: 0,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          );
        }),
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
          _plinkoScale = scale;
          return Stack(
            children: [
              Positioned.fill(
                child: Image.asset(
                  'assets/images/chief_trolls_wheel/bg.png',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      Container(color: const Color(0xFF2A1810)),
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
                      child: Center(
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [_buildPlinkoField(scale)],
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.only(bottom: 12 * scale),
                      child: _buildCoeffButtons(scale),
                    ),
                    Padding(
                      padding: EdgeInsets.only(bottom: 12 * scale),
                      child: _buildBottomControls(scale),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _FallingBall {
  final int id;
  double x;
  double y;
  double vx;
  double vy;
  int? chestIndex;
  int? win;
  _FallingBall({
    required this.id,
    required this.x,
    required this.y,
    this.vx = 0,
    this.vy = 0,
  });
}
