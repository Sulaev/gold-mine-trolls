import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gold_mine_trolls/services/analytics_service.dart';
import 'package:gold_mine_trolls/services/audio_service.dart';
import 'package:gold_mine_trolls/services/balance_service.dart';
import 'package:gold_mine_trolls/screens/shop_screen.dart';
import 'package:gold_mine_trolls/widgets/pressable_button.dart';
import 'package:gold_mine_trolls/widgets/warning_panel.dart';

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
  static const _floorsRequired = 6;

  static const _balanceStroke = Color(0x40000000);
  static const _balanceFill = Color(0xFFFFFFFF);
  static const _towerVisualScale = 1 / 1.5;

  static const _foundationWidth = 375.0;
  static const _foundationHeight = 217.0;
  static const _fieldWidth = 375.0;
  static const _fieldHeight = 610.0;
  static const _foundationBottom = -60.0;
  static const _hookTop = -74.0;
  static const _hookHeight = 285.0;
  static const _hookWidth = 70.0;
  static const _trossWidth = 150.0;
  static const _trossHeight = 37.0;
  static const _trossDownOffset = -20.0;
  static const _roomVisualTopInset = 20.0;
  static const _roomVisualBottomInset = 20.0;
  static const _foundationLandingLift = 60.0;
  static const _stackLandingExtraDown = 45.0;
  static const _roomSpawnTop = 206.0;
  static const _foundationSurfaceInsetTop = 136.0;
  static const _roomMoveSideMargin = 8.0;
  static const _roomMoveAmplitudeMinFactor = 0.72;
  static const _roomMoveAmplitudeMaxFactor = 0.96;
  static const _roomMoveBaseDurationMs = 2300;
  static const _roomMoveMinDurationMs = 850;
  static const _dropTolerance = 28.0;
  static const _placedRoomDownStep = 50.0;
  static const _hookLeftOffset = 28.0;
  static const _sinkDurationMs = 550;
  static const _crashDurationMs = 380;
  static const _failedDropHorizontalOffset = 52.0;
  static const _failedDropBottomInset = 34.0;
  static const _loseCardWidth = 262.0;
  static const _loseCardHeight = 174.0;
  static const _tryAgainButtonWidth = 204.0;
  static const _tryAgainButtonHeight = 45.0;
  static const _collectButtonWidth = 220.0;
  static const _collectButtonHeight = 54.0;
  static const _playButtonWidth = 295.0;
  static const _playButtonHeight = 65.0;
  static const _bottomControlsHeight = 150.0;
  static const _collectBottomOffset = 92.0;
  static const _multiplierTop = 108.0;
  static const _multiplierShiftRight = 140.0;
  static const _multiplierShiftDown = 150.0;

  static const _multiplierPlateWidth = 94.0;
  static const _multiplierPlateHeight = 51.0;
  static const _buildButtonWidth = 103.0;
  static const _buildButtonHeight = 58.0;

  static const _roomCatalog = <_RoomAsset>[
    _RoomAsset(
      asset: 'assets/images/mine_depth_tower/rooms/room1.png',
      sourceSize: Size(350, 281),
    ),
    _RoomAsset(
      asset: 'assets/images/mine_depth_tower/rooms/room2.png',
      sourceSize: Size(230, 281),
    ),
    _RoomAsset(
      asset: 'assets/images/mine_depth_tower/rooms/room3.png',
      sourceSize: Size(317, 249),
    ),
    _RoomAsset(
      asset: 'assets/images/mine_depth_tower/rooms/room4.png',
      sourceSize: Size(276, 249),
    ),
    _RoomAsset(
      asset: 'assets/images/mine_depth_tower/rooms/room5.png',
      sourceSize: Size(311, 255),
    ),
    _RoomAsset(
      asset: 'assets/images/mine_depth_tower/rooms/room6.png',
      sourceSize: Size(265, 255),
    ),
    _RoomAsset(
      asset: 'assets/images/mine_depth_tower/rooms/room7.png',
      sourceSize: Size(350, 281),
    ),
    _RoomAsset(
      asset: 'assets/images/mine_depth_tower/rooms/room8.png',
      sourceSize: Size(230, 281),
    ),
    _RoomAsset(
      asset: 'assets/images/mine_depth_tower/rooms/room9.png',
      sourceSize: Size(317, 249),
    ),
    _RoomAsset(
      asset: 'assets/images/mine_depth_tower/rooms/room10.png',
      sourceSize: Size(276, 249),
    ),
    _RoomAsset(
      asset: 'assets/images/mine_depth_tower/rooms/room11.png',
      sourceSize: Size(311, 255),
    ),
    _RoomAsset(
      asset: 'assets/images/mine_depth_tower/rooms/room12.png',
      sourceSize: Size(265, 255),
    ),
  ];

  final _rng = Random();
  final List<double> _multipliers = List.generate(17, (i) => 1.5 + i);

  late final AnimationController _roomMoveController;
  late final AnimationController _dropController;
  late final AnimationController _balanceCountController;
  late final AnimationController _sinkController;
  late final AnimationController _crashController;

  Timer? _adjustTimer;
  Stopwatch? _adjustWatch;

  int _balance = 0;
  int _displayBalance = 0;
  double _balanceAnimFrom = 0;
  int _bet = _baseBet;
  int _currentRoundWinAmount = 0;
  int _lastWinAmount = 0;
  int _activeDelta = 0;
  bool _loadingBalance = true;

  bool _roundActive = false;
  bool _isDropping = false;
  bool _isFailing = false;
  bool _isWinning = false;

  final List<_PlacedRoom> _placedRooms = <_PlacedRoom>[];
  _RoomAsset? _activeRoom;
  _RoomAsset? _droppingRoom;
  _RoomAsset? _crashRoom;
  Offset? _dropFrom;
  Offset? _dropTo;
  Offset? _crashTopLeft;
  bool _dropWillSucceed = false;
  double _crashDirection = 1;

  @override
  void initState() {
    super.initState();
    unawaited(AnalyticsService.reportGameStart(_gameName));
    _roomMoveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2300),
      value: 0,
    );
    _dropController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 560),
    )..addStatusListener(_onDropStatusChanged);
    _balanceCountController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 520),
        )..addListener(() {
          if (!mounted) return;
          final t = Curves.easeOutCubic.transform(
            _balanceCountController.value,
          );
          final next = (uiLerp(
            _balanceAnimFrom,
            _balance.toDouble(),
            t,
          )).round();
          if (next == _displayBalance) return;
          setState(() => _displayBalance = next);
        });
    _sinkController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: _sinkDurationMs),
        )..addListener(() {
          if (!mounted) return;
          setState(() {});
        });
    _crashController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: _crashDurationMs),
        )..addListener(() {
          if (!mounted) return;
          setState(() {});
        });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _precacheAssets();
    });
    _activeRoom = _pickNextRoom();
    _restartSwingAnimation();
    BalanceService.balanceNotifier.addListener(_onBalanceNotifierChanged);
    _loadBalance();
  }

  @override
  void dispose() {
    _adjustTimer?.cancel();
    _adjustWatch?.stop();
    BalanceService.balanceNotifier.removeListener(_onBalanceNotifierChanged);
    _adjustTimer?.cancel();
    _roomMoveController.dispose();
    _dropController.dispose();
    _balanceCountController.dispose();
    _sinkController.dispose();
    _crashController.dispose();
    super.dispose();
  }

  void _onBalanceNotifierChanged() {
    if (!mounted) return;
    final value = BalanceService.balanceNotifier.value;
    if (value == _balance) return;
    setState(() {
      _balance = value;
      _displayBalance = value;
      _balanceAnimFrom = value.toDouble();
    });
    _animateBalanceChange(durationMs: 520);
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

  Future<void> _precacheAssets() async {
    final assets = <String>[
      'assets/images/mine_depth_tower/bg_start.png',
      'assets/images/mine_depth_tower/foundation.png',
      'assets/images/mine_depth_tower/standart.png',
      'assets/images/mine_depth_tower/start_btn.png',
      'assets/images/mine_depth_tower/build_btn.png',
      'assets/images/mine_depth_tower/collect_btn.png',
      'assets/images/mine_depth_tower/play_btn.png',
      'assets/images/mine_depth_tower/lose.png',
      'assets/images/mine_depth_tower/trayagain_btn.png',
      'assets/images/gold_vein/win_back.png',
      'assets/images/mine_depth_tower/cruck.png',
      'assets/images/mine_depth_tower/tross.png',
      'assets/images/gold_vein/back_btn.png',
      'assets/images/gold_vein/minus_btn.png',
      'assets/images/gold_vein/plus_btn.png',
      'assets/images/gold_vein/coin_back2.png',
      'assets/images/gold_vein/maxbet_btn.png',
      'assets/images/main_screen/coin_icon.png',
      'assets/images/main_screen/add_btn.png',
      ..._roomCatalog.map((room) => room.asset),
    ];
    for (final asset in assets) {
      try {
        await precacheImage(AssetImage(asset), context);
      } catch (_) {}
    }
  }

  void _animateBalanceChange({int durationMs = 520}) {
    _balanceCountController.stop();
    _balanceAnimFrom = _displayBalance.toDouble();
    _balanceCountController.duration = Duration(milliseconds: durationMs);
    _balanceCountController.forward(from: 0);
  }

  double _screenScale(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return min(size.width / 390, size.height / 844).clamp(0.82, 1.3);
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

  Future<void> _applyBetDelta(int delta, {bool haptic = true}) async {
    if (_loadingBalance || _balance <= 0 || _roundActive || _isDropping) {
      return;
    }
    final next = (_bet + delta).clamp(_minBet, _balance);
    if (next == _bet) return;
    setState(() => _bet = next);
    unawaited(BalanceService.setLastBet(_bet));
    unawaited(AnalyticsService.reportBetChange(_gameName, _bet));
    if (haptic) HapticFeedback.selectionClick();
  }

  void _startContinuousBetAdjust(int delta) {
    _stopContinuousBetAdjust();
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
    if (_balance <= 0 || _bet == _balance || _roundActive) return;
    setState(() => _bet = _balance);
    unawaited(BalanceService.setLastBet(_bet));
    unawaited(AnalyticsService.reportBetChange(_gameName, _bet));
    HapticFeedback.lightImpact();
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

  double _currentMultiplierValue() {
    final index = _placedRooms.length.clamp(0, _multipliers.length - 1);
    return _multipliers[index];
  }

  _RoomAsset _pickNextRoom() {
    return _roomCatalog[_rng.nextInt(_roomCatalog.length)];
  }

  Size _scaledRoomSize(_RoomAsset room, double scale) {
    return Size(
      room.sourceSize.width * scale * _towerVisualScale,
      room.sourceSize.height * scale * _towerVisualScale,
    );
  }

  double _towerScaled(double value, double scale) {
    return value * scale * _towerVisualScale;
  }

  double _fieldCenterX(double scale) => (_fieldWidth * scale) / 2;

  double _foundationTop(double scale) {
    final fieldH = _fieldHeight * scale;
    final foundationH = _towerScaled(_foundationHeight, scale);
    final foundationBottom = _foundationBottom * scale;
    return fieldH - foundationBottom - foundationH;
  }

  double _foundationSurfaceY(double scale) {
    return _foundationTop(scale) +
        _towerScaled(_foundationSurfaceInsetTop, scale);
  }

  double _swingProgress() {
    if (_floorsRequired <= 1) return 1;
    return (_placedRooms.length / (_floorsRequired - 1)).clamp(0.0, 1.0);
  }

  int _currentSwingDurationMs() {
    final progress = _swingProgress();
    final duration =
        _roomMoveBaseDurationMs -
        ((_roomMoveBaseDurationMs - _roomMoveMinDurationMs) * progress).round();
    return duration.clamp(_roomMoveMinDurationMs, _roomMoveBaseDurationMs);
  }

  void _restartSwingAnimation() {
    if (_activeRoom == null) return;
    _roomMoveController
      ..stop()
      ..duration = Duration(milliseconds: _currentSwingDurationMs())
      ..forward(from: 0);
    _roomMoveController.repeat(reverse: true);
  }

  double _currentSwingCenterX(_RoomAsset room, double scale) {
    final t = Curves.easeInOutSine.transform(_roomMoveController.value);
    final roomSize = _scaledRoomSize(room, scale);
    final halfField = _fieldCenterX(scale);
    final maxAmplitude = max(
      0.0,
      halfField - (roomSize.width / 2) - (_roomMoveSideMargin * scale),
    );
    final progress = _swingProgress();
    final amplitudeFactor =
        _roomMoveAmplitudeMinFactor +
        ((_roomMoveAmplitudeMaxFactor - _roomMoveAmplitudeMinFactor) *
            progress);
    final amplitude = maxAmplitude * amplitudeFactor;
    return halfField + ((t * 2) - 1) * amplitude;
  }

  double _roomVisualTopInsetScaled(double scale) =>
      _towerScaled(_roomVisualTopInset, scale);

  double _roomVisualBottomInsetScaled(double scale) =>
      _towerScaled(_roomVisualBottomInset, scale);

  double _roomVisibleBottomOffset(Size roomSize, double scale) =>
      roomSize.height - _roomVisualBottomInsetScaled(scale);

  double _roomVisibleTopY(double renderedTop, double scale) =>
      renderedTop + _roomVisualTopInsetScaled(scale);

  double _restingPlacedRoomTop(int roomIndex, double scale) {
    final room = _placedRooms[roomIndex];
    return room.topLeft.dy +
        (_sinkPrefix(_placedRooms.length) - _sinkPrefix(roomIndex)) * scale;
  }

  Offset _failedDropTarget(
    _RoomAsset room,
    Offset from,
    double scale,
    double direction,
  ) {
    final roomSize = _scaledRoomSize(room, scale);
    final shiftedLeft =
        (from.dx + direction * (_failedDropHorizontalOffset * scale)).clamp(
          0.0,
          (_fieldWidth * scale) - roomSize.width,
        );
    final impactVisibleBottomY =
        (_fieldHeight * scale) - (_failedDropBottomInset * scale);
    final impactTop =
        impactVisibleBottomY - _roomVisibleBottomOffset(roomSize, scale);
    return Offset(shiftedLeft, impactTop);
  }

  Offset _roomTargetTopLeft(_RoomAsset room, double centerX, double scale) {
    final roomSize = _scaledRoomSize(room, scale);
    final targetVisibleBottomY = _placedRooms.isEmpty
        ? _foundationSurfaceY(scale) - (_foundationLandingLift * scale)
        : _roomVisibleTopY(
                _restingPlacedRoomTop(_placedRooms.length - 1, scale),
                scale,
              ) +
              (_stackLandingExtraDown * scale);
    final renderedTop =
        targetVisibleBottomY - _roomVisibleBottomOffset(roomSize, scale);
    return Offset(centerX - roomSize.width / 2, renderedTop);
  }

  Offset _activeRoomTopLeft(_RoomAsset room, double scale) {
    final roomSize = _scaledRoomSize(room, scale);
    return Offset(
      _currentSwingCenterX(room, scale) - roomSize.width / 2,
      _towerScaled(_roomSpawnTop, scale),
    );
  }

  bool get _isBuildLocked =>
      _loadingBalance ||
      _isDropping ||
      _sinkController.isAnimating ||
      _crashController.isAnimating ||
      _crashRoom != null ||
      _isFailing ||
      _isWinning;

  void _resetRoundState({bool keepOutcome = false}) {
    _stopContinuousBetAdjust();
    _sinkController.reset();
    _crashController.reset();
    setState(() {
      _placedRooms.clear();
      _roundActive = false;
      _isDropping = false;
      _droppingRoom = null;
      _crashRoom = null;
      _dropFrom = null;
      _dropTo = null;
      _crashTopLeft = null;
      _dropWillSucceed = false;
      _crashDirection = 1;
      _currentRoundWinAmount = 0;
      _lastWinAmount = 0;
      _activeRoom = _pickNextRoom();
      if (!keepOutcome) {
        _isFailing = false;
        _isWinning = false;
      }
    });
    _restartSwingAnimation();
  }

  void _collectWinnings() {
    if (_isDropping || _sinkController.isAnimating || _placedRooms.isEmpty) {
      return;
    }
    HapticFeedback.lightImpact();
    if (!_isWinning) {
      setState(() {
        _roundActive = false;
        _isWinning = true;
        _lastWinAmount = _currentRoundWinAmount;
        _activeRoom = null;
      });
      _crashController.forward(from: 0);
      unawaited(AudioService.instance.playWin());
      _roomMoveController.stop();
      return;
    }
    _resetRoundState();
  }

  void _retryAfterLose() {
    HapticFeedback.lightImpact();
    _resetRoundState();
  }

  Future<void> _onPrimaryButtonTap() async {
    if (_isBuildLocked) return;
    if (!_roundActive) {
      _startRound();
      await _dropCurrentRoom();
      return;
    }
    await _dropCurrentRoom();
  }

  void _startRound() {
    _sinkController.reset();
    setState(() {
      _placedRooms.clear();
      _roundActive = true;
      _isFailing = false;
      _isWinning = false;
      _currentRoundWinAmount = 0;
      _lastWinAmount = 0;
      _droppingRoom = null;
      _dropFrom = null;
      _dropTo = null;
      _activeRoom ??= _pickNextRoom();
    });
    HapticFeedback.lightImpact();
  }

  Future<void> _dropCurrentRoom() async {
    final room = _activeRoom;
    if (room == null) return;
    if (_bet <= 0 || _balance < _bet) {
      showWarningSnackBar(context, 'Not enough coins to start the game.');
      return;
    }

    final scale = _screenScale(context);
    final from = _activeRoomTopLeft(room, scale);
    final roomSize = _scaledRoomSize(room, scale);
    final targetCenter = _placedRooms.isEmpty
        ? _fieldCenterX(scale)
        : _placedRooms.last.centerX;
    final currentCenter = from.dx + roomSize.width / 2;
    final tolerance = _placedRooms.isEmpty
        ? 44 * scale
        : max(_dropTolerance * scale, _placedRooms.last.size.width * 0.26);
    final success = (currentCenter - targetCenter).abs() <= tolerance;
    final failDirection = currentCenter >= targetCenter ? 1.0 : -1.0;

    final to = success
        ? _roomTargetTopLeft(room, currentCenter, scale)
        : _failedDropTarget(room, from, scale, failDirection);

    setState(() {
      _balance -= _bet;
      _isDropping = true;
      _isFailing = false;
      _droppingRoom = room;
      _dropFrom = from;
      _dropTo = to;
      _dropWillSucceed = success;
      _crashDirection = failDirection;
      _activeRoom = null;
    });
    _animateBalanceChange(durationMs: 360);
    await BalanceService.setBalance(_balance);
    _roomMoveController.stop();
    _dropController.forward(from: 0);
    unawaited(AudioService.instance.playDrilling());
  }

  void _onDropStatusChanged(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    final room = _droppingRoom;
    final target = _dropTo;
    if (room == null || target == null) {
      _dropController.reset();
      return;
    }

    if (_dropWillSucceed) {
      final floorIndex = _placedRooms.length;
      final multiplier = _multipliers[min(floorIndex, _multipliers.length - 1)];
      final roomSize = _scaledRoomSize(room, _screenScale(context));
      final centerX = target.dx + roomSize.width / 2;
      final win = (_bet * multiplier).round();
      final nextPlacedCount = _placedRooms.length + 1;
      final completedTower = nextPlacedCount >= _floorsRequired;

      setState(() {
        _placedRooms.add(
          _PlacedRoom(
            asset: room.asset,
            sourceSize: room.sourceSize,
            topLeft: target,
            centerX: centerX,
            size: roomSize,
          ),
        );
        _balance += win;
        _currentRoundWinAmount += win;
        _droppingRoom = null;
        _dropFrom = null;
        _dropTo = null;
        _isDropping = false;
      });
      _animateBalanceChange(durationMs: 620);
      unawaited(BalanceService.setBalance(_balance));
      unawaited(AudioService.instance.playMineDepthTowerRoomDown());
      unawaited(AnalyticsService.reportGameWin(_gameName));
      _dropController.reset();
      final sinkFuture = _sinkController.forward(from: 0);

      sinkFuture.whenCompleteOrCancel(() {
        if (!mounted) return;
        if (completedTower) {
          setState(() {
            _roundActive = false;
            _isWinning = true;
            _lastWinAmount = _currentRoundWinAmount;
            _activeRoom = null;
          });
          _crashController.forward(from: 0);
          unawaited(AudioService.instance.playWin());
          _roomMoveController.stop();
          return;
        }
        setState(() => _activeRoom = _pickNextRoom());
        _restartSwingAnimation();
      });
      if (completedTower) {
        HapticFeedback.heavyImpact();
      } else {
        HapticFeedback.mediumImpact();
      }
    } else {
      unawaited(AnalyticsService.reportGameLoss(_gameName));
      _roomMoveController.stop();
      _sinkController.reset();
      setState(() {
        _roundActive = false;
        _placedRooms.clear();
        _crashRoom = null;
        _crashTopLeft = null;
        _droppingRoom = null;
        _dropFrom = null;
        _dropTo = null;
        _isDropping = false;
        _activeRoom = null;
        _isFailing = true;
      });
      _dropController.reset();
      _crashController.forward(from: 0);
      unawaited(AudioService.instance.playLose());
      HapticFeedback.heavyImpact();
    }
  }

  Widget _buildTopBar(double scale) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 14 * scale),
      child: SizedBox(
        height: 86 * scale,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: PressableButton(
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
            ),
            _buildBalance(scale),
          ],
        ),
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

  Widget _buildMultiplierPlate(double scale) {
    final multiplier = _currentMultiplierValue();
    final text = 'x${multiplier.toStringAsFixed(1)}';
    final fontSize = 19 * scale;
    final strokeWidth = 0.85 * scale;
    return Positioned(
      top: (_multiplierTop + _multiplierShiftDown) * scale,
      left: 0,
      right: 0,
      child: Transform.translate(
        offset: Offset(_multiplierShiftRight * scale, 0),
        child: Center(
          child: Transform.rotate(
            angle: -20 * pi / 180,
            child: SizedBox(
              width: _multiplierPlateWidth * scale,
              height: _multiplierPlateHeight * scale,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Image.asset(
                    'assets/images/mine_depth_tower/standart.png',
                    fit: BoxFit.fill,
                  ),
                  Text(
                    text,
                    style: TextStyle(
                      fontFamily: 'Gotham',
                      fontWeight: FontWeight.w900,
                      fontSize: fontSize,
                      height: 1.2,
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
                      height: 1.2,
                      color: const Color(0xFFF3FF45),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  double _totalSinkOffset(double scale) {
    final n = _placedRooms.length;
    if (n == 0) return 0;
    final beforeCurrent = _sinkPrefix(n - 1);
    final currentStep = _sinkStepForPlacement(n);
    return (beforeCurrent + currentStep * _sinkController.value) * scale;
  }

  double _sinkStepForPlacement(int placedCount) {
    if (placedCount <= 3) return _placedRoomDownStep;
    return _placedRoomDownStep * 2;
  }

  double _sinkPrefix(int placementsCount) {
    var total = 0.0;
    for (var i = 1; i <= placementsCount; i++) {
      total += _sinkStepForPlacement(i);
    }
    return total;
  }

  Widget _buildGameField(double scale) {
    final fieldW = _fieldWidth * scale;
    final fieldH = _fieldHeight * scale;
    final foundationW = _towerScaled(_foundationWidth, scale);
    final foundationH = _towerScaled(_foundationHeight, scale);
    final totalSink = _totalSinkOffset(scale);

    return SizedBox(
      width: fieldW,
      height: fieldH,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: (fieldW - foundationW) / 2,
            bottom: (_foundationBottom * scale) - totalSink,
            child: SizedBox(
              width: foundationW,
              height: foundationH,
              child: Image.asset(
                'assets/images/mine_depth_tower/foundation.png',
                fit: BoxFit.fill,
              ),
            ),
          ),
          for (final room in _placedRooms) _buildPlacedRoom(room, scale),
          if (_crashRoom != null && _crashTopLeft != null)
            _buildCrashRoom(scale),
          if (_activeRoom != null && !_isDropping) _buildHangingRig(scale),
          if (_droppingRoom != null && _dropFrom != null)
            _buildReleasedRig(scale),
          if (_droppingRoom != null && _dropFrom != null && _dropTo != null)
            _buildDroppingRoom(scale),
          if (_activeRoom != null && !_isDropping) _buildActiveRoom(scale),
        ],
      ),
    );
  }

  Widget _buildPlacedRoom(_PlacedRoom room, double scale) {
    final roomIndex = _placedRooms.indexOf(room);
    final totalSink = _totalSinkOffset(scale);
    final roomSinkPrefix = _sinkPrefix(roomIndex) * scale;
    final extraDownShift = totalSink - roomSinkPrefix;
    return Positioned(
      left: room.topLeft.dx,
      top: room.topLeft.dy + extraDownShift,
      child: SizedBox(
        width: room.size.width,
        height: room.size.height,
        child: Image.asset(
          room.asset,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
        ),
      ),
    );
  }

  Widget _buildActiveRoom(double scale) {
    final room = _activeRoom!;
    final roomSize = _scaledRoomSize(room, scale);
    final topLeft = _activeRoomTopLeft(room, scale);
    return Positioned(
      left: topLeft.dx,
      top: topLeft.dy,
      child: AnimatedBuilder(
        animation: _roomMoveController,
        builder: (context, child) {
          final updated = _activeRoomTopLeft(room, scale);
          return Transform.translate(
            offset: Offset(updated.dx - topLeft.dx, 0),
            child: child,
          );
        },
        child: SizedBox(
          width: roomSize.width,
          height: roomSize.height,
          child: Image.asset(
            room.asset,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) =>
                const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }

  Widget _buildHangingRig(double scale) {
    final room = _activeRoom!;
    final roomSize = _scaledRoomSize(room, scale);
    final hookTop = _towerScaled(_hookTop, scale);
    final hookW = _towerScaled(_hookWidth, scale);
    final hookH = _towerScaled(_hookHeight, scale);
    final trossW = _towerScaled(_trossWidth, scale);
    final trossH = _towerScaled(_trossHeight, scale);
    final trossDownOffset = _trossDownOffset * scale;
    final startLeft = _activeRoomTopLeft(room, scale).dx;
    final initialCenterX = startLeft + roomSize.width / 2;
    final initialRoomTop = _activeRoomTopLeft(room, scale).dy;
    final initialTrossTop = max(
      0.0,
      initialRoomTop - hookTop - trossH - trossDownOffset,
    );
    final rigHeight = initialTrossTop + trossH;
    final rigWidth = max(hookW, trossW);

    return Positioned(
      left: initialCenterX - hookW / 2 - (_hookLeftOffset * scale),
      top: hookTop,
      child: AnimatedBuilder(
        animation: _roomMoveController,
        builder: (context, child) {
          final currentLeft = _activeRoomTopLeft(room, scale).dx;
          final currentCenterX = currentLeft + roomSize.width / 2;
          final currentRoomTop = _activeRoomTopLeft(room, scale).dy;
          final currentTrossTop = max(
            0.0,
            currentRoomTop - hookTop - trossH - trossDownOffset,
          );
          return Transform.translate(
            offset: Offset(currentCenterX - initialCenterX, 0),
            child: SizedBox(
              width: rigWidth,
              height: rigHeight,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    top: 0,
                    left: (rigWidth - hookW) / 2,
                    child: SizedBox(
                      width: hookW,
                      height: hookH,
                      child: Image.asset(
                        'assets/images/mine_depth_tower/cruck.png',
                        fit: BoxFit.fill,
                      ),
                    ),
                  ),
                  Positioned(
                    top: currentTrossTop,
                    left: (rigWidth - trossW) / 2,
                    child: SizedBox(
                      width: trossW,
                      height: trossH,
                      child: Image.asset(
                        'assets/images/mine_depth_tower/tross.png',
                        fit: BoxFit.fill,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildReleasedRig(double scale) {
    final from = _dropFrom!;
    final room = _droppingRoom!;
    final roomSize = _scaledRoomSize(room, scale);
    final hookW = _towerScaled(_hookWidth, scale);
    final hookH = _towerScaled(_hookHeight, scale);
    final trossW = _towerScaled(_trossWidth, scale);
    final trossH = _towerScaled(_trossHeight, scale);
    final trossDownOffset = _trossDownOffset * scale;
    final centerX = from.dx + roomSize.width / 2;
    final hookTop = _towerScaled(_hookTop, scale);
    final trossTop = max(0.0, from.dy - hookTop - trossH - trossDownOffset);
    final rigHeight = trossTop + trossH;
    final rigWidth = max(hookW, trossW);
    return Positioned(
      left: centerX - max(hookW, trossW) / 2 - (_hookLeftOffset * scale),
      top: hookTop,
      child: SizedBox(
        width: rigWidth,
        height: rigHeight,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              top: 0,
              left: (rigWidth - hookW) / 2,
              child: SizedBox(
                width: hookW,
                height: hookH,
                child: Image.asset(
                  'assets/images/mine_depth_tower/cruck.png',
                  fit: BoxFit.fill,
                ),
              ),
            ),
            Positioned(
              top: trossTop,
              left: (rigWidth - trossW) / 2,
              child: SizedBox(
                width: trossW,
                height: trossH,
                child: Image.asset(
                  'assets/images/mine_depth_tower/tross.png',
                  fit: BoxFit.fill,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDroppingRoom(double scale) {
    final room = _droppingRoom!;
    final from = _dropFrom!;
    final to = _dropTo!;
    final roomSize = _scaledRoomSize(room, scale);
    return AnimatedBuilder(
      animation: _dropController,
      builder: (context, child) {
        final t = Curves.easeInCubic.transform(_dropController.value);
        final dx = from.dx + (to.dx - from.dx) * t;
        final dy = from.dy + (to.dy - from.dy) * t;
        final angle = _dropWillSucceed ? 0.0 : (_crashDirection * 0.9 * t);
        return Positioned(
          left: dx,
          top: dy,
          child: Transform.rotate(
            angle: angle,
            alignment: Alignment.center,
            child: child!,
          ),
        );
      },
      child: SizedBox(
        width: roomSize.width,
        height: roomSize.height,
        child: Image.asset(
          room.asset,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
        ),
      ),
    );
  }

  Widget _buildCrashRoom(double scale) {
    final room = _crashRoom!;
    final topLeft = _crashTopLeft!;
    final roomSize = _scaledRoomSize(room, scale);
    return Positioned(
      left: topLeft.dx,
      top: topLeft.dy,
      child: SizedBox(
        width: roomSize.width,
        height: roomSize.height,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            AnimatedBuilder(
              animation: _crashController,
              builder: (context, child) {
                final t = Curves.easeOutCubic.transform(_crashController.value);
                return Transform.translate(
                  offset: Offset(-18 * scale * t, 16 * scale * t),
                  child: Transform.rotate(
                    angle: -0.42 * _crashDirection * t,
                    alignment: Alignment.centerRight,
                    child: Opacity(opacity: 1 - (t * 0.45), child: child),
                  ),
                );
              },
              child: ClipRect(
                child: Align(
                  alignment: Alignment.centerLeft,
                  widthFactor: 0.5,
                  child: Image.asset(
                    room.asset,
                    width: roomSize.width,
                    height: roomSize.height,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) =>
                        const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
            AnimatedBuilder(
              animation: _crashController,
              builder: (context, child) {
                final t = Curves.easeOutCubic.transform(_crashController.value);
                return Transform.translate(
                  offset: Offset(24 * scale * t, 22 * scale * t),
                  child: Transform.rotate(
                    angle: 0.58 * _crashDirection * t,
                    alignment: Alignment.centerLeft,
                    child: Opacity(opacity: 1 - (t * 0.55), child: child),
                  ),
                );
              },
              child: ClipRect(
                child: Align(
                  alignment: Alignment.centerRight,
                  widthFactor: 0.5,
                  child: Image.asset(
                    room.asset,
                    width: roomSize.width,
                    height: roomSize.height,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) =>
                        const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBetControl(double scale) {
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
                        style: TextStyle(
                          fontFamily: 'Gotham',
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

  Widget _buildBottomBar(double scale) {
    final buttonAsset = _roundActive
        ? 'assets/images/mine_depth_tower/build_btn.png'
        : 'assets/images/mine_depth_tower/start_btn.png';
    return SizedBox(
      height: _bottomControlsHeight * scale,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          if (_roundActive && _placedRooms.isNotEmpty)
            Positioned(
              bottom: _collectBottomOffset * scale,
              child: _buildCollectButton(scale),
            ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 18 * scale),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _buildBetControl(scale),
                SizedBox(width: 16 * scale),
                IgnorePointer(
                  ignoring: _isBuildLocked,
                  child: PressableButton(
                    onTap: _onPrimaryButtonTap,
                    child: AnimatedOpacity(
                      opacity: _isBuildLocked ? 0.6 : 1,
                      duration: const Duration(milliseconds: 140),
                      child: SizedBox(
                        width: _buildButtonWidth * scale,
                        height: _buildButtonHeight * scale,
                        child: Image.asset(buttonAsset, fit: BoxFit.fill),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCollectButton(double scale) {
    return PressableButton(
      onTap: _collectWinnings,
      child: SizedBox(
        width: _collectButtonWidth * scale,
        height: _collectButtonHeight * scale,
        child: Image.asset(
          'assets/images/mine_depth_tower/collect_btn.png',
          fit: BoxFit.fill,
        ),
      ),
    );
  }

  Widget _buildWinCollectButton(double scale) {
    return PressableButton(
      onTap: _collectWinnings,
      child: SizedBox(
        width: _playButtonWidth * scale,
        height: _playButtonHeight * scale,
        child: Image.asset(
          'assets/images/mine_depth_tower/play_btn.png',
          fit: BoxFit.fill,
        ),
      ),
    );
  }

  Widget _buildWinOverlay(double scale) {
    final boardWidth = MediaQuery.of(context).size.width;
    final boardHeight = MediaQuery.of(context).size.height;
    final jackpotNumber = 51.52 * scale;
    final amountText = _formatAmount(_lastWinAmount);
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

    return SizedBox(
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
    );
  }

  Widget _buildLoseContent(double scale) {
    final fade = CurvedAnimation(
      parent: _crashController,
      curve: Curves.easeOutCubic,
    );
    return FadeTransition(
      opacity: fade,
      child: SafeArea(
        child: Column(
          children: [
            SizedBox(height: 4 * scale),
            _buildTopBar(scale),
            Expanded(
              child: Center(
                child: SizedBox(
                  width: _loseCardWidth * scale,
                  height: _loseCardHeight * scale,
                  child: Image.asset(
                    'assets/images/mine_depth_tower/lose.png',
                    fit: BoxFit.fill,
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.only(bottom: 18 * scale),
              child: PressableButton(
                onTap: _retryAfterLose,
                child: SizedBox(
                  width: _tryAgainButtonWidth * scale,
                  height: _tryAgainButtonHeight * scale,
                  child: Image.asset(
                    'assets/images/mine_depth_tower/trayagain_btn.png',
                    fit: BoxFit.fill,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWinContent(double scale) {
    final fade = CurvedAnimation(
      parent: _crashController,
      curve: Curves.easeOutCubic,
    );
    return FadeTransition(
      opacity: fade,
      child: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(child: Center(child: _buildGameField(scale))),
            Positioned.fill(
              child: IgnorePointer(
                child: Container(color: const Color(0x66000000)),
              ),
            ),
            _buildMultiplierPlate(scale),
            Center(child: _buildWinOverlay(scale)),
            Positioned(
              top: 4 * scale,
              left: 0,
              right: 0,
              child: _buildTopBar(scale),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 18 * scale,
              child: Center(child: _buildWinCollectButton(scale)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGameContent(double scale) {
    const topBarHeight = 86.0;
    return SafeArea(
      child: Stack(
        children: [
          Column(
            children: [
              SizedBox(height: (4 + topBarHeight) * scale),
              Expanded(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: Center(child: _buildGameField(scale)),
                    ),
                    _buildMultiplierPlate(scale),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.only(bottom: 14 * scale),
                child: Transform.translate(
                  offset: Offset(0, 15 * scale),
                  child: _buildBottomBar(scale),
                ),
              ),
            ],
          ),
          Positioned(
            top: 4 * scale,
            left: 0,
            right: 0,
            child: _buildTopBar(scale),
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
                  'assets/images/mine_depth_tower/bg_start.png',
                  fit: BoxFit.cover,
                ),
              ),
              if (_isFailing)
                _buildLoseContent(scale)
              else if (_isWinning)
                _buildWinContent(scale)
              else
                _buildGameContent(scale),
            ],
          );
        },
      ),
    );
  }
}

class _RoomAsset {
  const _RoomAsset({required this.asset, required this.sourceSize});

  final String asset;
  final Size sourceSize;
}

class _PlacedRoom {
  const _PlacedRoom({
    required this.asset,
    required this.sourceSize,
    required this.topLeft,
    required this.centerX,
    required this.size,
  });

  final String asset;
  final Size sourceSize;
  final Offset topLeft;
  final double centerX;
  final Size size;
}

double uiLerp(double a, double b, double t) => a + (b - a) * t;
