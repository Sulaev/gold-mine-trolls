import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gold_mine_trolls/models/blackjack_card.dart';
import 'package:gold_mine_trolls/models/blackjack_game.dart';
import 'package:gold_mine_trolls/screens/info_screen.dart';
import 'package:gold_mine_trolls/screens/shop_screen.dart';
import 'package:gold_mine_trolls/services/analytics_service.dart';
import 'package:gold_mine_trolls/services/audio_service.dart';
import 'package:gold_mine_trolls/services/balance_service.dart';
import 'package:gold_mine_trolls/services/card_mine_21_storage.dart';
import 'package:gold_mine_trolls/widgets/pressable_button.dart';
import 'package:gold_mine_trolls/widgets/tap_banner.dart';

class CardMine21Screen extends StatefulWidget {
  const CardMine21Screen({super.key});

  @override
  State<CardMine21Screen> createState() => _CardMine21ScreenState();
}

class _CardMine21ScreenState extends State<CardMine21Screen>
    with TickerProviderStateMixin {
  static const _gameName = 'card_mine_21';
  static const _balanceStroke = Color(0x40000000);
  static const _balanceFill = Color(0xFFFFFFFF);
  static const _cardWidth = 99.0;
  static const _cardHeight = 129.0;
  static const _cardSpacing = 12.0;
  static const _fixedBet = 10000;
  static const _fixedWin = 30000;

  int _balance = 0;
  int _displayBalance = 0;
  double _balanceAnimFrom = 0;
  int _lastWin = 0;
  bool _loadingBalance = true;

  late final AnimationController _balanceCountController;
  late final AnimationController _notificationController;
  late final AnimationController _winCountController;
  final BlackjackGame _game = BlackjackGame();
  bool _gameStarted = false;
  bool _dealerRevealed = false;
  bool _dealerDrawLoopRunning = false;
  bool _isWinOverlayVisible = false;
  bool _winOverlayShownForRound = false;
  bool _showResultOverlay = false;
  static const _resultDelay = Duration(milliseconds: 1200);
  int _overlayTargetWin = 0;
  int _overlayAnimatedWin = 0;

  @override
  void initState() {
    super.initState();
    unawaited(AnalyticsService.reportGameStart(_gameName));
    _balanceCountController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    )..addListener(() {
        if (!mounted) return;
        final t = Curves.easeOutCubic.transform(_balanceCountController.value);
        final next =
            (_balanceAnimFrom + (_balance - _balanceAnimFrom) * t).round();
        if (next == _displayBalance) return;
        setState(() => _displayBalance = next);
      });
    _notificationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _winCountController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..addListener(() {
        if (!mounted || !_isWinOverlayVisible) return;
        final t = Curves.easeOutCubic.transform(_winCountController.value);
        setState(() => _overlayAnimatedWin = (_overlayTargetWin * t).round());
      });
    BalanceService.balanceNotifier.addListener(_onBalanceNotifierChanged);
    _loadBalance();
    _startGame();
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

  Future<void> _startGame() async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    if (_gameStarted) return;
    final saved = await CardMine21Storage.loadGame();
    if (saved != null) {
      _restoreGame(saved);
      return;
    }
    await _startRoundWithBet();
  }

  void _restoreGame(Map<String, dynamic> saved) {
    if (!mounted) return;
    try {
      final deck = saved['deck'] as List?;
      if (deck == null || deck.isEmpty) {
        unawaited(CardMine21Storage.clearGame());
        return;
      }
      setState(() {
        _game.restoreState(saved);
        _dealerRevealed = _game.phase == BlackjackPhase.dealerTurn ||
            _game.isGameOver;
        _gameStarted = true;
        _winOverlayShownForRound = false;
        _handlePhaseChanged();
      });
      if (_game.phase == BlackjackPhase.dealerTurn && _game.dealerNeedsToDraw) {
        _dealerDrawLoop();
      }
    } catch (_) {
      unawaited(CardMine21Storage.clearGame());
    }
  }

  Future<void> _saveGameState() async {
    final state = _game.saveState();
    if (state != null) {
      await CardMine21Storage.saveGame(state);
    }
  }

  @override
  void dispose() {
    BalanceService.balanceNotifier.removeListener(_onBalanceNotifierChanged);
    _balanceCountController.dispose();
    _notificationController.dispose();
    _winCountController.dispose();
    super.dispose();
  }

  Future<void> _loadBalance() async {
    final value = await BalanceService.getBalance();
    if (!mounted) return;
    setState(() {
      _balance = value;
      _displayBalance = value;
      _balanceAnimFrom = value.toDouble();
      _loadingBalance = false;
    });
    final saved = await CardMine21Storage.loadGame();
    if (saved != null && !_gameStarted) {
      _restoreGame(saved);
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
          const ShopScreen(source: 'card_mine_21'),
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
                  'The goal of the game is to get as close to 21 as possible without going over.\n\n'
                  'You play against the dealer. Cards from 2 to 10 count as their face value. '
                  'Jack, Queen, and King count as 10. Ace counts as 1 or 11 — whichever is better for you.\n\n'
                  'Buttons:\n'
                  'Hit — take one more card\n'
                  'Stand — keep your current cards\n\n'
                  'If your total is higher than the dealer\'s and does not exceed 21, you win. '
                  'If your total goes over 21, you lose the round.\n\n'
                  'Good luck and enjoy the game!',
                  textAlign: TextAlign.center,
                  style: InfoScreen.mainTextStyle(),
                ),
              ),
            ),
          ),
    );
  }

  void _onHit() {
    if (!_game.canHit) return;
    HapticFeedback.lightImpact();
    setState(() {
      _game.hit();
      _handlePhaseChanged();
    });
    unawaited(AudioService.instance.playCardDrop());
    unawaited(_saveGameState());
  }

  void _onStand() {
    if (!_game.canStand) return;
    HapticFeedback.lightImpact();
    setState(() {
      _game.stand();
      _dealerRevealed = true;
      _handlePhaseChanged();
    });
    unawaited(_saveGameState());
    _dealerDrawLoop();
  }

  Future<void> _dealerDrawLoop() async {
    if (_dealerDrawLoopRunning) return;
    _dealerDrawLoopRunning = true;
    try {
      var iterations = 0;
      const maxIterations = 12;
      while (_game.dealerNeedsToDraw && mounted && iterations < maxIterations) {
        iterations++;
        await Future<void>.delayed(const Duration(milliseconds: 500));
        if (!mounted) return;
        setState(() {
          _game.dealerDrawOne();
          _handlePhaseChanged();
        });
        unawaited(AudioService.instance.playCardDrop());
        unawaited(_saveGameState());
      }
      if (mounted) unawaited(_saveGameState());
    } finally {
      _dealerDrawLoopRunning = false;
    }
  }

  Future<void> _newRound() async {
    _dismissWinOverlay();
    await _startRoundWithBet();
  }

  Future<void> _startRoundWithBet() async {
    if (!mounted) return;
    if (_balance < _fixedBet) return;

    await CardMine21Storage.clearGame();

    final nextBalance = _balance - _fixedBet;
    setState(() {
      _balance = nextBalance;
      _game.startNewRound();
      _dealerRevealed = false;
      _winOverlayShownForRound = false;
      _showResultOverlay = false;
      _notificationController.reset();
      _gameStarted = true;
      _lastWin = 0;
      _handlePhaseChanged();
    });
    for (var i = 0; i < 4; i++) {
      unawaited(
        Future<void>.delayed(Duration(milliseconds: i * 80))
            .then((_) => AudioService.instance.playCardDrop()),
      );
    }
    _animateBalanceChange(durationMs: 520);
    await BalanceService.setBalance(nextBalance);
    unawaited(_saveGameState());
  }

  bool get _isLoseState =>
      _game.phase == BlackjackPhase.dealerWin ||
      _game.phase == BlackjackPhase.playerBust;
  bool get _isWinState =>
      _game.phase == BlackjackPhase.playerWin ||
      _game.phase == BlackjackPhase.dealerBust;

  void _handlePhaseChanged() {
    if (_game.isGameOver) {
      unawaited(CardMine21Storage.clearGame());
    }
    if (_isWinState && !_winOverlayShownForRound) {
      final winAmount = _fixedWin;
      _lastWin = winAmount;
      _winOverlayShownForRound = true;
      unawaited(AnalyticsService.reportGameWin(_gameName));
      unawaited(AudioService.instance.playWin());
      _showWinOverlay(winAmount);
      _creditWinPayout(winAmount);
    }
    if (_isLoseState && !_showResultOverlay) {
      unawaited(AnalyticsService.reportGameLoss(_gameName));
      unawaited(
        Future<void>.delayed(_resultDelay).then((_) {
          if (!mounted) return;
          unawaited(AudioService.instance.playLose());
          setState(() => _showResultOverlay = true);
          _notificationController.forward(from: 0);
        }),
      );
    }
    if (_game.phase == BlackjackPhase.push) {
      unawaited(_redealOnPush());
    }
  }

  Future<void> _redealOnPush() async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    await CardMine21Storage.clearGame();
    if (!mounted) return;
    setState(() {
      _game.startNewRound();
      _dealerRevealed = false;
      _winOverlayShownForRound = false;
      _showResultOverlay = false;
      _notificationController.reset();
      _handlePhaseChanged();
    });
    for (var i = 0; i < 4; i++) {
      unawaited(
        Future<void>.delayed(Duration(milliseconds: i * 80))
            .then((_) => AudioService.instance.playCardDrop()),
      );
    }
    unawaited(_saveGameState());
  }

  Future<void> _creditWinPayout(int amount) async {
    final nextBalance = _balance + amount;
    if (!mounted) return;
    setState(() => _balance = nextBalance);
    _animateBalanceChange(durationMs: 760);
    await BalanceService.setBalance(nextBalance);
  }

  void _showWinOverlay(int amount) {
    _overlayTargetWin = amount;
    _overlayAnimatedWin = 0;
    _isWinOverlayVisible = true;
    _notificationController.forward(from: 0);
    _winCountController.forward(from: 0);
  }

  void _dismissWinOverlay() {
    if (!_isWinOverlayVisible) return;
    _notificationController.reverse();
    if (!mounted) return;
    setState(() => _isWinOverlayVisible = false);
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

  Widget _buildCardPlace(double scale) {
    return SizedBox(
      width: _cardWidth * scale,
      height: _cardHeight * scale,
      child: Image.asset(
        'assets/images/card_mine_21/card_place.png',
        fit: BoxFit.fill,
      ),
    );
  }

  Widget _buildTableLabel(String text, double scale) {
    final size = 21.29 * scale;
    return Stack(
      children: [
        Text(
          text.toUpperCase(),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Gotham',
            fontWeight: FontWeight.w900,
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
                offset: Offset(0, 1.99),
                blurRadius: 0,
              ),
            ],
          ),
        ),
        Text(
          text.toUpperCase(),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Gotham',
            fontWeight: FontWeight.w900,
            fontSize: size,
            height: 1.6,
            letterSpacing: -0.02 * size,
            color: const Color(0xFFFFFFFF),
            shadows: const [
              Shadow(
                color: Color(0x40000000),
                offset: Offset(0, 1.99),
                blurRadius: 0,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFlyingCard({
    required BlackjackCard card,
    required int slotIndex,
    required int durationIndex,
    required bool isDealer,
    required bool faceDown,
    required double scale,
    required double screenWidth,
  }) {
    return TweenAnimationBuilder<double>(
      key: ValueKey('${isDealer ? 'd' : 'p'}_$slotIndex'),
      tween: Tween(begin: 1, end: 0),
      duration: Duration(milliseconds: 350 + (durationIndex * 80)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset((screenWidth * 0.5 + _cardWidth) * value, 0),
          child: child,
        );
      },
      child: SizedBox(
        width: _cardWidth * scale,
        height: _cardHeight * scale,
        child: Stack(
          children: [
            _buildCardPlace(scale),
            Image.asset(
              faceDown
                  ? 'assets/images/card_mine_21/card/back.png'
                  : card.assetPath,
              fit: BoxFit.fill,
              width: _cardWidth * scale,
              height: _cardHeight * scale,
            ),
          ],
        ),
      ),
    );
  }

  double _cardLeft(int i, double cardW, double spacing) {
    if (i < 2) return i * (cardW + spacing);
    return 2 * (cardW + spacing) + (i - 2) * (cardW * 0.7);
  }

  double _handWidth(int count, double cardW, double spacing) {
    if (count <= 1) return cardW;
    if (count == 2) return 2 * cardW + spacing;
    return 2 * (cardW + spacing) + (count - 2) * (cardW * 0.7);
  }

  Widget _buildCardArea(double scale, double screenWidth) {
    final cardW = _cardWidth * scale;
    final cardH = _cardHeight * scale;
    final spacing = _cardSpacing * scale;
    final dealerCountForWidth =
        _game.dealerHand.length < 2 ? 2 : _game.dealerHand.length;
    final playerCountForWidth =
        _game.playerHand.length < 2 ? 2 : _game.playerHand.length;
    final dealerHandWidth = _handWidth(dealerCountForWidth, cardW, spacing);
    final playerHandWidth = _handWidth(playerCountForWidth, cardW, spacing);
    final rowWidth =
        dealerHandWidth > playerHandWidth ? dealerHandWidth : playerHandWidth;
    final slotWidth = 2 * cardW + spacing;
    final dealerCardsLeft = (rowWidth - dealerHandWidth) / 2;
    final playerCardsLeft = (rowWidth - playerHandWidth) / 2;
    final dealerSlotsLeft = (rowWidth - slotWidth) / 2;
    final playerSlotsLeft = (rowWidth - slotWidth) / 2;
    final labelH = 34.0 * scale;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Dealer label
        SizedBox(
          width: 140 * scale,
          height: labelH,
          child: Center(
            child: _buildTableLabel(
              _dealerRevealed
                  ? 'DILLER: ${_game.dealerValue}'
                  : 'DILLER:',
              scale,
            ),
          ),
        ),
        SizedBox(height: 6 * scale),
        // Dealer card row
        SizedBox(
          width: rowWidth,
          height: cardH,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              if (_game.dealerHand.isEmpty)
                Positioned(
                  left: dealerSlotsLeft,
                  top: 0,
                  child: _buildCardPlace(scale),
                ),
              if (_game.dealerHand.length < 2)
                Positioned(
                  left: dealerSlotsLeft + cardW + spacing,
                  top: 0,
                  child: _buildCardPlace(scale),
                ),
              ...List.generate(_game.dealerHand.length, (i) {
                final card = _game.dealerHand[i];
                final showFace = _dealerRevealed;
                return Positioned(
                  left: dealerCardsLeft + _cardLeft(i, cardW, spacing),
                  top: 0,
                  child: _buildFlyingCard(
                    card: card,
                    slotIndex: i,
                    durationIndex: i,
                    isDealer: true,
                    faceDown: !showFace,
                    scale: scale,
                    screenWidth: screenWidth,
                  ),
                );
              }),
            ],
          ),
        ),
        SizedBox(height: 20 * scale),
        // Player label
        SizedBox(
          width: 140 * scale,
          height: labelH,
          child: Center(
            child: _buildTableLabel(
              _game.playerHand.isEmpty
                  ? 'YOU CARD:'
                  : 'YOU CARD: ${_game.playerValue}',
              scale,
            ),
          ),
        ),
        SizedBox(height: 6 * scale),
        // Player card row
        SizedBox(
          width: rowWidth,
          height: cardH,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              if (_game.playerHand.isEmpty)
                Positioned(
                  left: playerSlotsLeft,
                  top: 0,
                  child: _buildCardPlace(scale),
                ),
              if (_game.playerHand.length < 2)
                Positioned(
                  left: playerSlotsLeft + cardW + spacing,
                  top: 0,
                  child: _buildCardPlace(scale),
                ),
              ...List.generate(_game.playerHand.length, (i) {
                final card = _game.playerHand[i];
                return Positioned(
                  left: playerCardsLeft + _cardLeft(i, cardW, spacing),
                  top: 0,
                  child: _buildFlyingCard(
                    card: card,
                    slotIndex: i,
                    durationIndex: 2 + i,
                    isDealer: false,
                    faceDown: false,
                    scale: scale,
                    screenWidth: screenWidth,
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildYouWin(double scale) {
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
    );
  }

  Widget _buildBottomControls(double scale) {
    if (_isLoseState) {
      final invisibleYouWin = SizedBox(
        width: 260 * scale,
        height: 91 * scale,
      );
      if (_showResultOverlay) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            invisibleYouWin,
            SizedBox(width: 236 * scale, height: 52 * scale),
            SizedBox(height: 12 * scale),
            PressableButton(
              onTap: () async {
                HapticFeedback.lightImpact();
                await _newRound();
              },
              child: SizedBox(
                width: 204 * scale,
                height: 45 * scale,
                child: Image.asset(
                  'assets/images/card_mine_21/trayagain_btn.png',
                  fit: BoxFit.fill,
                ),
              ),
            ),
          ],
        );
      }
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          invisibleYouWin,
          SizedBox(width: 236 * scale, height: 52 * scale),
          SizedBox(height: 12 * scale),
          SizedBox(width: 208 * scale, height: 45 * scale),
        ],
      );
    }

    if (_isWinState) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildYouWin(scale),
          // Keep layout height identical to normal state so table does not jump.
          SizedBox(
            width: 236 * scale,
            height: 52 * scale,
          ),
          SizedBox(height: 12 * scale),
          SizedBox(
            width: 208 * scale,
            height: 45 * scale,
          ),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildYouWin(scale),
        PressableButton(
          onTap: _onHit,
          child: SizedBox(
            width: 236 * scale,
            height: 52 * scale,
            child: Image.asset(
              'assets/images/card_mine_21/hit_btn.png',
              fit: BoxFit.fill,
            ),
          ),
        ),
        SizedBox(height: 12 * scale),
        PressableButton(
          onTap: _onStand,
          child: SizedBox(
            width: 208 * scale,
            height: 45 * scale,
            child: Image.asset(
              'assets/images/card_mine_21/stand_btn.png',
              fit: BoxFit.fill,
            ),
          ),
        ),
      ],
    );
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
          child: Center(
            child: Transform.translate(
              offset: Offset(0, -12 * scale),
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
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final scale = (constraints.maxWidth / 390).clamp(0.82, 1.3).toDouble();
          final screenWidth = constraints.maxWidth;
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
                        child: _gameStarted
                            ? _isLoseState && _showResultOverlay
                                ? FadeTransition(
                                    opacity: CurvedAnimation(
                                      parent: _notificationController,
                                      curve: Curves.easeOut,
                                    ),
                                    child: SizedBox(
                                      width: 262 * scale,
                                      height: 174 * scale,
                                      child: Image.asset(
                                        'assets/images/card_mine_21/lose.png',
                                        fit: BoxFit.fill,
                                      ),
                                    ),
                                  )
                                : _isLoseState
                                    ? Column(
                                        mainAxisSize: MainAxisSize.min,
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          _buildCardArea(scale, screenWidth),
                                        ],
                                      )
                                    : Column(
                                    mainAxisSize: MainAxisSize.min,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      _buildCardArea(scale, screenWidth),
                                    ],
                                  )
                            : Text(
                                'Card Mine 21',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 18 * scale,
                                ),
                              ),
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
                    onTap: () {
                      HapticFeedback.lightImpact();
                      _dismissWinOverlay();
                    },
                    behavior: HitTestBehavior.opaque,
                    child: FadeTransition(
                      opacity: CurvedAnimation(
                        parent: _notificationController,
                        curve: Curves.easeOut,
                      ),
                      child: Container(
                        color: const Color(0x70000000),
                        child: Center(child: _buildWinOverlay(scale)),
                      ),
                    ),
                  ),
                ),
              if (_isWinState)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: (12 * scale) + (30 * scale),
                  child: Center(
                    child: PressableButton(
                      onTap: () async {
                        HapticFeedback.lightImpact();
                        await _newRound();
                      },
                      child: SizedBox(
                        width: 300 * scale,
                        height: 65 * scale,
                        child: Image.asset(
                          'assets/images/card_mine_21/play_btn.png',
                          fit: BoxFit.fill,
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
