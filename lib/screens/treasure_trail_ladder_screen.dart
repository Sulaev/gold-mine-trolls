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

class TreasureTrailLadderScreen extends StatefulWidget {
  const TreasureTrailLadderScreen({super.key});

  @override
  State<TreasureTrailLadderScreen> createState() =>
      _TreasureTrailLadderScreenState();
}

class _TreasureTrailLadderScreenState extends State<TreasureTrailLadderScreen>
    with TickerProviderStateMixin {
  static const _gameName = 'treasure_trail_ladder';
  static const _minBet = 50;
  static const _baseBet = 10000;
  static const _betStep = 50;
  static const _rows = 8;
  static const _visibleRows = 8;
  static const _cols = 5;
  static const _cellSize = 48.0;
  static const _cellGap = 0.0;
  static const _balanceStroke = Color(0x40000000);
  static const _balanceFill = Color(0xFFFFFFFF);

  static const _rowLoseCounts = <int>[1, 1, 2, 2, 2, 3, 3, 4];
  static const _rowMultipliers = <double>[
    1.23,
    1.64,
    2.40,
    3.11,
    11.65,
    37.21,
    11.18,
    69.93,
  ];

  final _rng = math.Random();
  late final AnimationController _balanceCountController;
  late final AnimationController _notificationController;
  late final AnimationController _winCountController;

  int _balance = 0;
  int _displayBalance = 0;
  double _balanceAnimFrom = 0;
  int _bet = _baseBet;
  int _activeRow = 0; // 0 is bottom row
  int _potentialWin = 0;
  bool _loadingBalance = true;
  bool _inRun = false;
  bool _isGameOver = false;
  bool _isWinOverlayVisible = false;
  bool _isResolvingPick = false;
  int _overlayTargetWin = 0;
  int _overlayAnimatedWin = 0;

  Timer? _adjustTimer;
  Stopwatch? _adjustWatch;
  int _activeDelta = 0;

  // true = gold, false = dynamite
  List<List<bool>> _rowMap = List.generate(
    _visibleRows,
    (_) => List.filled(_cols, true),
  );
  final Set<int> _revealed = <int>{};
  final Set<int> _selected = <int>{};

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
          duration: const Duration(milliseconds: 1500),
        )..addListener(() {
          if (!mounted || !_isWinOverlayVisible) return;
          final t = Curves.easeOutCubic.transform(_winCountController.value);
          setState(() => _overlayAnimatedWin = (_overlayTargetWin * t).round());
        });
    _generateRows();
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
          const ShopScreen(source: 'treasure_trail_ladder'),
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
          InfoScreen(
            content: Padding(
              padding: const EdgeInsets.only(top: 70, left: 40, right: 40),
              child: SingleChildScrollView(
                child: Text(
                  'The game consists of 10 levels, each featuring 5 cells. Your goal is to choose the right cell to progress. '
                  'On every level, you must open one of the five cells. As you advance, the chances of winning decrease, making the game more challenging.\n'
                  'Each cell hides either a gold nugget or a spider web.\n'
                  'If you open a cell with a gold nugget, you win the round, your winnings increase, and you move to the next level.\n'
                  'If you open a cell with a spider web, you lose everything and the game ends.\n'
                  'You can stop at any time and cash out your current winnings.',
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

  void _generateRows() {
    _rowMap = List.generate(_visibleRows, (rowIndex) {
      final profile = rowIndex;
      final loses = _rowLoseCounts[profile];
      final list = List<bool>.filled(_cols, true);
      final loseIndexes = <int>{};
      while (loseIndexes.length < loses) {
        loseIndexes.add(_rng.nextInt(_cols));
      }
      for (final i in loseIndexes) {
        list[i] = false;
      }
      return list;
    });
  }

  int _cellKey(int row, int col) => row * 100 + col;

  Future<void> _applyBetDelta(int delta, {bool haptic = true}) async {
    if (_loadingBalance || _balance <= 0 || _inRun) return;
    final next = (_bet + delta).clamp(_minBet, _balance);
    if (next == _bet) return;
    setState(() => _bet = next);
    await BalanceService.setLastBet(_bet);
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
      unawaited(_applyBetDelta(_activeDelta * _betStep * factor, haptic: false));
    });
  }

  void _stopContinuousBetAdjust() {
    _adjustTimer?.cancel();
    _adjustTimer = null;
    _adjustWatch?.stop();
    _adjustWatch = null;
  }

  Future<void> _setQuickBet(int nextBet) async {
    if (_loadingBalance || _balance <= 0 || _inRun || _isGameOver) return;
    final next = nextBet.clamp(_minBet, _balance);
    if (next == _bet) return;
    setState(() => _bet = next);
    await BalanceService.setLastBet(_bet);
    unawaited(AnalyticsService.reportBetChange(_gameName, _bet));
    HapticFeedback.selectionClick();
  }

  Widget _buildQuickBetButtons(double scale) {
    Widget quickBtn(String asset, VoidCallback onTap) {
      return PressableButton(
        onTap: onTap,
        child: SizedBox(
          width: 74 * scale,
          height: 42 * scale,
          child: Image.asset(asset, fit: BoxFit.fill),
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        quickBtn(
          'assets/images/treasure_trail_ladder/min.png',
          () => _setQuickBet(_minBet),
        ),
        SizedBox(width: 6 * scale),
        quickBtn(
          'assets/images/treasure_trail_ladder/x2.png',
          () => _setQuickBet(_bet * 2),
        ),
        SizedBox(width: 6 * scale),
        quickBtn(
          'assets/images/treasure_trail_ladder/y2.png',
          () => _setQuickBet(_bet ~/ 2),
        ),
        SizedBox(width: 6 * scale),
        quickBtn(
          'assets/images/treasure_trail_ladder/max.png',
          () => _setQuickBet(_balance),
        ),
      ],
    );
  }

  Future<void> _startRun() async {
    if (_loadingBalance || _inRun || _isGameOver) return;
    if (_bet <= 0 || _balance < _bet) {
      showWarningSnackBar(
        context,
        'Not enough coins to start the game.',
      );
      return;
    }
    final nextBalance = _balance - _bet;
    setState(() {
      _balance = nextBalance;
      _revealed.clear();
      _selected.clear();
      _activeRow = 0;
      _potentialWin = 0;
      _inRun = true;
      _isResolvingPick = false;
      _isWinOverlayVisible = false;
    });
    _generateRows();
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
      _isResolvingPick = false;
      _revealed.clear();
      _selected.clear();
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
    if (_loadingBalance) return;
    if (_isResolvingPick) return;
    if (!_inRun) {
      await _startRun();
      if (!_inRun || !mounted) return;
    }
    if (_activeRow >= _rows) return;
    if (row != _activeRow) return;
    final key = _cellKey(row, col);
    if (_revealed.contains(key) || _selected.contains(key)) {
      return;
    }

    final isGold = _rowMap[row][col];
    if (isGold) unawaited(AudioService.instance.playTreasureTrailLadderClaim());
    setState(() {
      _isResolvingPick = true;
      _selected.add(key);
      _revealed.add(key);
    });
    HapticFeedback.selectionClick();
    if (!mounted) return;
    setState(() {
      for (var c = 0; c < _cols; c++) {
        if (c == col) continue;
        _revealed.add(_cellKey(row, c));
      }
    });

    if (isGold) {
      final nextPotential = (_bet * _rowMultipliers[_activeRow]).round();
      setState(() {
        _potentialWin = nextPotential;
        _activeRow += 1;
        _isResolvingPick = false;
        _selected.clear();
      });
      return;
    }

    setState(() {
      _inRun = false;
      _potentialWin = 0;
      _isResolvingPick = false;
      _selected.clear();
    });
    unawaited(AnalyticsService.reportGameLoss(_gameName));
    unawaited(AudioService.instance.playLose());
    await Future.delayed(const Duration(milliseconds: 450));
    if (!mounted) return;
    setState(() {
      _revealed.clear();
      _isGameOver = true;
    });
  }

  void _restartAfterLose() {
    if (!_isGameOver) return;
    setState(() {
      _isGameOver = false;
      _inRun = false;
      _isResolvingPick = false;
      _activeRow = 0;
      _potentialWin = 0;
      _revealed.clear();
      _selected.clear();
      _generateRows();
    });
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
    final boardHeight = MediaQuery.of(context).size.height;
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
          height: boardHeight,
          child: Stack(
            alignment: Alignment.topCenter,
            children: [
              Transform.translate(
                offset: Offset(0, 190 * scale),
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
              Align(
                alignment: Alignment.bottomCenter,
                child: Transform.translate(
                  offset: Offset(0, 120 * scale),
                  child: SizedBox(
                    width: math.min(532 * scale, boardWidth * 0.92),
                    height: math.min(736 * scale, boardHeight * 0.62),
                    child: Image.asset(
                      'assets/images/treasure_trail_ladder/troll.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
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
                        const MinersPassScreen(source: 'treasure_trail_ladder'),
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
        57 * scale +
        8 * scale +
        _cols * _cellSize * scale +
        (_cols - 1) * _cellGap * scale;
    return SizedBox(
      width: boardWidth,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var displayRow = _visibleRows - 1; displayRow >= 0; displayRow--)
            Padding(
              padding: EdgeInsets.only(
                bottom: displayRow == 0 ? 0 : _cellGap * scale,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildMultiplierBadge(displayRow, scale),
                  SizedBox(width: 8 * scale),
                  for (var col = 0; col < _cols; col++)
                    Padding(
                      padding: EdgeInsets.only(
                        right: col == _cols - 1 ? 0 : _cellGap * scale,
                      ),
                      child: _buildCell(displayRow, col, scale),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMultiplierBadge(int row, double scale) {
    final mult = _rowMultipliers[row];
    final text = 'x${mult.toStringAsFixed(2)}';
    final fontSize = 13.15 * scale;
    final strokeWidth = 0.62 * scale;

    return SizedBox(
      width: 57 * scale,
      height: 31 * scale,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Image.asset(
            'assets/images/treasure_trail_ladder/standart.png',
            fit: BoxFit.fill,
          ),
          Text(
            text,
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
            text,
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
        ],
      ),
    );
  }

  Widget _buildCell(int row, int col, double scale) {
    final key = _cellKey(row, col);
    final isRevealed = _revealed.contains(key);
    final isSelected = _selected.contains(key);
    final isOpen = isRevealed;
    final isGold = _rowMap[row][col];
    final isCurrent =
        !_isGameOver &&
        ((_inRun && row == _activeRow) || (!_inRun && row == 0));
    final closedCardAsset = isCurrent
        ? 'assets/images/treasure_trail_ladder/cube_sicret.png'
        : 'assets/images/treasure_trail_ladder/rectangle.png';

    return PressableButton(
      onTap: () => _onTileTap(row, col),
      child: SizedBox(
        width: _cellSize * scale,
        height: _cellSize * scale,
        child: AnimatedScale(
          scale: (isSelected && !isOpen) ? 1.1 : 1,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutBack,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                isOpen
                    ? 'assets/images/treasure_trail_ladder/open_card.png'
                    : closedCardAsset,
                fit: BoxFit.cover,
              ),
              if (isOpen)
                Image.asset(
                  isGold
                      ? 'assets/images/treasure_trail_ladder/gold.png'
                      : 'assets/images/treasure_trail_ladder/pautin.png',
                  fit: BoxFit.contain,
                ),
              if (isCurrent && !isOpen)
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10 * scale),
                    border: Border.all(
                      color: const Color(0xFFFFEA4C),
                      width: 2 * scale,
                    ),
                  ),
                ),
              if (isSelected)
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10 * scale),
                    border: Border.all(
                      color: const Color(0xFFFFFFFF),
                      width: 2 * scale,
                    ),
                  ),
                ),
            ],
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
                  : 'assets/images/treasure_trail_ladder/start_btn.png',
              fit: BoxFit.fill,
            ),
          ),
        ),
      ],
    );
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
                _buildLastWinValue(_formatWinAmount(_potentialWin), scale),
              ],
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
                child: Stack(
                  children: [
                    if (!_isGameOver)
                      Positioned.fill(
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: Transform.translate(
                            // Let grid pass under top HUD elements.
                            offset: Offset(0, 178 * scale),
                            child: _buildGrid(scale),
                          ),
                        ),
                      ),
                    Column(
                      children: [
                        SizedBox(height: 8 * scale),
                        _buildTopBar(scale),
                        SizedBox(height: 6 * scale),
                        _buildBalance(scale),
                        const Spacer(),
                        if (!_isGameOver)
                          Padding(
                            padding: EdgeInsets.only(bottom: 6 * scale),
                            child: _buildYouWinBanner(scale),
                          ),
                        if (!_isGameOver)
                          Padding(
                            padding: EdgeInsets.only(bottom: 8 * scale),
                            child: _buildQuickBetButtons(scale),
                          ),
                        if (!_isGameOver)
                          Padding(
                            padding: EdgeInsets.only(bottom: 12 * scale),
                            child: _buildBottomControls(scale),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              if (_isGameOver)
                Positioned.fill(
                  child: IgnorePointer(
                    child: Center(
                      child: SizedBox(
                        width: 262 * scale,
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
