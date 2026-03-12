import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gold_mine_trolls/screens/info_screen.dart';
import 'package:gold_mine_trolls/screens/miners_pass_screen.dart';
import 'package:gold_mine_trolls/screens/shop_screen.dart';
import 'package:gold_mine_trolls/services/analytics_service.dart';
import 'package:gold_mine_trolls/services/audio_service.dart';
import 'package:gold_mine_trolls/services/balance_service.dart';
import 'package:gold_mine_trolls/widgets/pressable_button.dart';
import 'package:gold_mine_trolls/widgets/tap_banner.dart';
import 'package:gold_mine_trolls/widgets/warning_panel.dart';

class CautiousMinerScreen extends StatefulWidget {
  const CautiousMinerScreen({super.key});

  @override
  State<CautiousMinerScreen> createState() => _CautiousMinerScreenState();
}

class _CautiousMinerScreenState extends State<CautiousMinerScreen>
    with TickerProviderStateMixin {
  static const _gameName = 'cautious_miner';
  static const _minBet = 50;
  static const _baseBet = 10000;
  static const _betStep = 50;
  static const _rows = 8;
  static const _cols = 5;
  static const _cellSize = 64.0;
  static const _cellGap = 0.0;
  static const _balanceStroke = Color(0x40000000);
  static const _balanceFill = Color(0xFFFFFFFF);
  static const _winProbability = 0.6; // 60/40 towards win.

  final _rng = math.Random();
  late final AnimationController _balanceCountController;
  late final AnimationController _notificationController;
  late final AnimationController _winCountController;
  Timer? _winOverlayAutoHideTimer;
  Timer? _adjustTimer;
  Stopwatch? _adjustWatch;
  final int _activeDelta = 0;

  int _balance = 0;
  int _displayBalance = 0;
  double _balanceAnimFrom = 0;
  int _bet = _baseBet;
  int _potentialWin = 0;
  bool _loadingBalance = true;
  bool _inRun = false;
  bool _isGameOver = false;
  bool _isWinOverlayVisible = false;
  int _overlayTargetWin = 0;
  int _overlayAnimatedWin = 0;

  Timer? _adjustTimer;
  Stopwatch? _adjustWatch;
  int _activeDelta = 0;

  // true = gold, false = dynamite
  List<List<bool>> _cellMap = List.generate(
    _rows,
    (_) => List.filled(_cols, true),
  );
  final Set<int> _revealed = <int>{};
  final Set<int> _breaking = <int>{};

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
    _notificationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _winCountController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 1400),
        )..addListener(() {
          if (!mounted || !_isWinOverlayVisible) return;
          final t = Curves.easeOutCubic.transform(_winCountController.value);
          setState(() => _overlayAnimatedWin = (_overlayTargetWin * t).round());
        });
    _generateMinefield();
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
    _winOverlayAutoHideTimer?.cancel();
    _adjustTimer?.cancel();
    _adjustWatch?.stop();
    _balanceCountController.dispose();
    _notificationController.dispose();
    _winCountController.dispose();
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
          const ShopScreen(source: 'cautious_miner'),
    );
  }

  void _openInfoDialog() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close info',
      barrierColor: const Color(0x80000000),
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, animation, secondaryAnimation) => InfoScreen(
        content: Padding(
          padding: const EdgeInsets.only(top: 70, left: 40, right: 40),
          child: SingleChildScrollView(
            child: Text(
              'Get ready to test your intuition in this round! Your goal is to find safe tiles and avoid hitting a mine.\n'
              'In front of you is a grid of hidden tiles. Each tile may contain a prize in the form of Golden Trolls Coins.\n'
              'Your move: Tap any tile to make your choice.\n'
              'If the tile lights up and Golden Trolls Coins appear - you win! Your current winnings increase, and you can either continue or cash out.\n'
              'If you hit a mine - the round is over and your entire bet is lost.\n'
              'With each correct pick in a row, your multiplier grows rapidly.\n'
              'You can cash out your accumulated winnings in Golden Trolls Coins at any time before hitting a mine.',
              textAlign: TextAlign.center,
              style: InfoScreen.mainTextStyle(),
            ),
          ),
        ),
      ),
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

  void _generateMinefield() {
    _cellMap = List.generate(_rows, (_) {
      return List.generate(_cols, (_) => _rng.nextDouble() < _winProbability);
    });
  }

  int _cellKey(int row, int col) => row * 100 + col;

  Future<void> _applyBetDelta(int delta, {bool haptic = true}) async {
    if (_loadingBalance || _balance <= 0 || _inRun || _isGameOver) return;
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

  Future<void> _startRun() async {
    if (_loadingBalance || _inRun || _isGameOver) return;
    if (_bet <= 0 || _balance < _bet) {
      showWarningSnackBar(context, 'Not enough coins to start the game.');
      return;
    }
    final nextBalance = _balance - _bet;
    _generateMinefield();
    setState(() {
      _balance = nextBalance;
      _revealed.clear();
      _breaking.clear();
      _potentialWin = 0;
      _inRun = true;
      _isWinOverlayVisible = false;
    });
    _animateBalanceChange(durationMs: 420);
    await BalanceService.setBalance(nextBalance);
  }

  Future<void> _collect() async {
    if (!_inRun) return;
    final wonAmount = _potentialWin;
    final next = _balance + wonAmount;
    setState(() {
      _balance = next;
      _inRun = false;
      _potentialWin = 0;
      _revealed.clear();
      _breaking.clear();
    });
    _animateBalanceChange(durationMs: 760);
    await BalanceService.setBalance(next);
    HapticFeedback.lightImpact();
    if (wonAmount > 0) {
      unawaited(AnalyticsService.reportGameWin(_gameName));
      unawaited(AudioService.instance.playWin());
      _showWinOverlay(wonAmount);
    }
  }

  Future<void> _onTileTap(int row, int col) async {
    if (_loadingBalance || _isGameOver) return;
    if (!_inRun) {
      await _startRun();
      if (!_inRun || !mounted) return;
    }

    final key = _cellKey(row, col);
    if (_revealed.contains(key) || _breaking.contains(key)) return;

    setState(() => _breaking.add(key));
    HapticFeedback.selectionClick();
    await Future.delayed(const Duration(milliseconds: 140));
    if (!mounted) return;

    final isGold = _cellMap[row][col];
    setState(() {
      _breaking.remove(key);
      _revealed.add(key);
    });

    if (isGold) {
      unawaited(AudioService.instance.playGoldenAvalancheCoin());
      setState(() {
        _potentialWin = _potentialWin == 0 ? _bet * 2 : _potentialWin * 2;
      });
      return;
    }

    setState(() {
      _inRun = false;
      _potentialWin = 0;
    });
    unawaited(AnalyticsService.reportGameLoss(_gameName));
    unawaited(AudioService.instance.playCautiousMinerBoom());
    await Future.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;
    setState(() {
      _revealed.clear();
      _breaking.clear();
      _isGameOver = true;
    });
  }

  void _restartAfterLose() {
    if (!_isGameOver) return;
    setState(() {
      _isGameOver = false;
      _inRun = false;
      _potentialWin = 0;
      _revealed.clear();
      _breaking.clear();
      _generateMinefield();
    });
  }

  void _showWinOverlay(int amount) {
    _winOverlayAutoHideTimer?.cancel();
    setState(() {
      _isWinOverlayVisible = true;
      _overlayTargetWin = amount;
      _overlayAnimatedWin = 0;
    });
    _notificationController.forward(from: 0);
    _winCountController.forward(from: 0);
    _winOverlayAutoHideTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      _dismissWinOverlay();
    });
  }

  void _dismissWinOverlay() {
    if (!_isWinOverlayVisible) return;
    _notificationController.reverse();
    setState(() => _isWinOverlayVisible = false);
  }

  Widget _buildWinOverlay(double scale) {
    final boardWidth = MediaQuery.of(context).size.width;
    final jackpotNumber = 51.52 * scale;
    final amountText = _formatAmount(_overlayAnimatedWin);
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              outlinedText('YOU WIN!', 33.8 * scale),
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
              outlinedText('YOU WIN!', 33.8 * scale),
            ],
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
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        const MinersPassScreen(source: 'cautious_miner'),
                  ),
                );
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

  Widget _buildGrid(double scale) {
    final boardWidth =
        _cols * _cellSize * scale + (_cols - 1) * _cellGap * scale;
    return SizedBox(
      width: boardWidth,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var row = _rows - 1; row >= 0; row--)
            Padding(
              padding: EdgeInsets.only(bottom: row == 0 ? 0 : _cellGap * scale),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var col = 0; col < _cols; col++)
                    Padding(
                      padding: EdgeInsets.only(
                        right: col == _cols - 1 ? 0 : _cellGap * scale,
                      ),
                      child: _buildCell(row, col, scale),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCell(int row, int col, double scale) {
    final key = _cellKey(row, col);
    final isRevealed = _revealed.contains(key);
    final isBreaking = _breaking.contains(key);
    final isGold = _cellMap[row][col];

    return PressableButton(
      onTap: () => _onTileTap(row, col),
      child: SizedBox(
        width: _cellSize * scale,
        height: _cellSize * scale,
        child: isRevealed
            ? Image.asset(
                isGold
                    ? 'assets/images/cautious_miner/gold.png'
                    : 'assets/images/cautious_miner/dynamit.png',
                fit: BoxFit.contain,
              )
            : AnimatedScale(
                scale: isBreaking ? 0.84 : 1,
                duration: const Duration(milliseconds: 120),
                curve: Curves.easeOut,
                child: AnimatedOpacity(
                  opacity: isBreaking ? 0.45 : 1,
                  duration: const Duration(milliseconds: 120),
                  child: Image.asset(
                    'assets/images/cautious_miner/block.png',
                    fit: BoxFit.cover,
                  ),
                ),
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
        SizedBox(width: 16 * scale),
        PressableButton(
          onTap: _inRun ? _collect : _startRun,
          child: SizedBox(
            width: 110 * scale,
            height: 62 * scale,
            child: Image.asset(
              _inRun
                  ? 'assets/images/cautious_miner/collect.png'
                  : 'assets/images/cautious_miner/play_btn.png',
              fit: BoxFit.fill,
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
          final scale = math
              .min(constraints.maxWidth / 390, constraints.maxHeight / 844)
              .clamp(0.82, 1.3);
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
                      child: Center(
                        child: _isGameOver
                            ? const SizedBox.shrink()
                            : _buildGrid(scale),
                      ),
                    ),
                    if (!_isGameOver)
                      Padding(
                        padding: EdgeInsets.only(
                          bottom: (12 * scale - 2).clamp(4.0, 20.0),
                        ),
                        child: _buildBottomControls(scale),
                      ),
                  ],
                ),
              ),
              if (_isGameOver)
                Positioned.fill(
                  child: IgnorePointer(
                    child: Center(
                      child: SizedBox(
                        width: 261 * scale,
                        height: 174 * scale,
                        child: Image.asset(
                          'assets/images/cautious_miner/lose.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                ),
              if (_isGameOver)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 26 * scale,
                  child: Center(
                    child: PressableButton(
                      onTap: _restartAfterLose,
                      child: SizedBox(
                        width: 205 * scale,
                        height: 45 * scale,
                        child: Image.asset(
                          'assets/images/cautious_miner/trayagain_btn.png',
                          fit: BoxFit.fill,
                        ),
                      ),
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
