import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show Ticker;
import 'package:flutter/services.dart';
import 'package:gold_mine_trolls/app_route_observer.dart';
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
    with TickerProviderStateMixin, RouteAware {
  static const _gameName = 'mine_depth_tower';
  static const _betStep = 50;
  static const _minBet = 50;
  static const _baseBet = 10000;
  static const _floorsRequired = 12;

  static const _balanceStroke = Color(0x40000000);
  static const _balanceFill = Color(0xFFFFFFFF);
  static const _towerVisualScale = 1 / 1.5;
  static const _roomsAndFoundationScale = 0.85; // −15%

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
  static const _trossOffsetUp = 5.0; // опустить тросс на 10 px (было 15)
  static const _roomOffsetDownOnHook = 0.0;
  static const _roomOnlyOffsetDown = 0.0; // опустить только комнату, не тросс/крюк
  static const _roomVisualTopInset = 20.0;
  static const _roomVisualBottomInset = 20.0;
  static const _foundationLandingLift = 60.0;
  static const _stackLandingExtraDown = 45.0;
  static const _roomSpawnTop = 206.0;
  static const _foundationSurfaceInsetTop = 136.0;
  static const _roomMoveSideMargin = 8.0;
  static const _roomMoveAmplitudeMinFactor = 0.72;
  static const _roomMoveAmplitudeMaxFactor = 0.96;
  /// ~+25px с каждой стороны при типичной длине троса (scale≈1)
  static const _hookSwingMaxAngleRad = 0.48;
  static const _roomMoveBaseDurationMs = 1133; // ~×1.5 быстрее полного размаха
  static const _roomMoveMinDurationMs = 213;
  static const _dropTolerance = 28.0;
  static const _placedRoomDownStep = 32.0; // было 50 — меньше опускание
  static const _hookLeftOffset = 28.0;
  static const _sinkDurationMs = 550;
  /// Физика промаха (как Golden Avalanche): гравитация в пикселях/с² при scale≈1
  static const _failGravity = 2100.0;
  static const _failBlockBounce = 0.54;
  static const _failWallBounce = 0.46;
  /// Меньше AABB — падает вниз, не «скользит» по всей ширине башни
  static const _failPhysBodyScale = 0.5;
  /// Коллизии башни/фундамента уже визуальной модели (по ширине)
  static const _towerCollisionWidthFactor = 0.5;
  /// Первые кадры без коллизий — нет рывка в случайную сторону
  static const _failPhysCollisionDelayTicks = 8;
  /// Сдвиг верха AABB вниз — приземление ниже визуальной крыши, меньше «прыжков в воздухе»
  static const _failTowerCollisionTopInset = 54.0;
  /// Нижняя грань комнаты должна провалиться ниже «крыши» на столько, чтобы засчитать опору
  static const _failLandMinPenetration = 14.0;
  static const _failAirVxDamp = 0.985;
  static const _failOmegaDamp = 0.94;
  static const _failAngCornerMax = 5.2; // rad/s — только уголком, без «вертушки»
  static const _winFadeDurationMs = 450;
  static const _losePanelFadeMs = 420;
  static const _loseZoneMargin = 75.0; // меньше победная зона
  static const _requiredOverlapFactor = 0.52; // больше перекрытие для победы
  static const _loseCardWidth = 262.0;
  static const _loseCardHeight = 174.0;
  static const _tryAgainButtonWidth = 204.0;
  static const _tryAgainButtonHeight = 45.0;
  static const _collectButtonWidth = 220.0;
  static const _collectButtonHeight = 54.0;
  static const _bottomControlsHeight = 150.0;
  static const _betControlHeight = 96.0;
  static const _betControlInstrumentTop = 7.0;
  static const _collectGapFromInstrument = 1.0;
  // Collect выше инструмента ставки, чтобы не перекрывался
  static double _collectBottomOffset(double scale) =>
      (_bottomControlsHeight - _betControlHeight + _betControlInstrumentTop) *
          scale +
      _collectGapFromInstrument +
      34;
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
      placeOffsetY: 10,
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
      placeOffsetY: 10,
    ),
    _RoomAsset(
      asset: 'assets/images/mine_depth_tower/rooms/room8.png',
      sourceSize: Size(230, 281),
    ),
    _RoomAsset(
      asset: 'assets/images/mine_depth_tower/rooms/room9.png',
      sourceSize: Size(317, 249),
      placeOffsetY: 10,
    ),
    _RoomAsset(
      asset: 'assets/images/mine_depth_tower/rooms/room10.png',
      sourceSize: Size(276, 249),
    ),
    _RoomAsset(
      asset: 'assets/images/mine_depth_tower/rooms/room11.png',
      sourceSize: Size(311, 255),
      placeOffsetY: 8,
    ),
    _RoomAsset(
      asset: 'assets/images/mine_depth_tower/rooms/room12.png',
      sourceSize: Size(265, 255),
    ),
  ];

  /// Чёткая очередность этажей: 1, 3, 5, 7, 9, 11, 5, 4, 10, 12, 2, 8
  static const _roomSequence = [
    0, 2, 4, 6, 8, 10, 4, 3, 9, 11, 1, 7,
  ]; // room1, room3, room5, room7, room9, room11, room5, room4, room10, room12, room2, room8

  final _rng = Random();

  /// Этаж 0: x1, этаж 1: x1.4, этаж 2: x1.8, затем до x30 на этаже 11
  double _baseMultiplierForFloor(int floorIndex) {
    if (floorIndex <= 2) return 1 + floorIndex * 0.4;
    return 1.8 + (floorIndex - 2) * (30 - 1.8) / 9;
  }

  int? _activeRoomBonusType;
  int? _droppingRoomBonusType;

  late final AnimationController _roomMoveController;
  late final AnimationController _dropController;
  late final AnimationController _balanceCountController;
  late final AnimationController _sinkController;
  late final AnimationController _losePanelController;
  late final AnimationController _winFadeController;
  late final AnimationController _winCountController;

  int _overlayTargetWin = 0;
  int _overlayAnimatedWin = 0;

  Timer? _adjustTimer;
  Timer? _loseOverlayTimer;
  Timer? _winOverlayTimer;
  /// Защита от двойного нажатия Collect до перерисовки (иначе второй вызов сразу сбрасывал раунд).
  bool _collectWinTransitionPending = false;
  Stopwatch? _adjustWatch;

  int _balance = 0;
  int _displayBalance = 0;
  double _balanceAnimFrom = 0;
  int _bet = _baseBet;
  int _currentRoundWinAmount = 0;
  int _lastWinAmount = 0;
  int _activeDelta = 0;
  bool _loadingBalance = true;

  /// Совпадает с scale поля из LayoutBuilder (не полный экран MediaQuery — иначе коллизии промаха «уезжают» вниз на узких экранах).
  double _gameLayoutScale = 1.0;

  bool _roundActive = false;
  bool _isDropping = false;
  bool _isFailing = false;
  bool _isWinning = false;

  final List<_PlacedRoom> _placedRooms = <_PlacedRoom>[];
  _RoomAsset? _activeRoom;
  _RoomAsset? _droppingRoom;
  Offset? _dropFrom;
  Offset? _dropTo;
  bool _dropWillSucceed = false;
  double _crashDirection = 1;
  Ticker? _failPhysicsTicker;
  bool _failPhysActive = false;
  _RoomAsset? _failPhysRoom;
  double _failPx = 0;
  double _failPy = 0;
  double _failVx = 0;
  double _failVy = 0;
  double _failPhysW = 0;
  double _failPhysH = 0;
  double _failAngleRad = 0;
  double _failOmegaRadPerSec = 0;
  int _failPhysTicks = 0;

  final GlobalKey _fieldKey = GlobalKey();
  final GlobalKey _foundationKey = GlobalKey();
  final GlobalKey _hangingRoomKey = GlobalKey();
  bool _routeObserverSubscribed = false;

  @override
  void initState() {
    super.initState();
    unawaited(AnalyticsService.reportGameStart(_gameName));
    _roomMoveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1533),
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
    _losePanelController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: _losePanelFadeMs),
        )..addListener(() {
          if (!mounted) return;
          setState(() {});
        });
    _winFadeController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: _winFadeDurationMs),
        )..addListener(() {
          if (!mounted) return;
          setState(() {});
        });
    _winCountController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 2200),
        )..addListener(() {
          if (!mounted || !_isWinning) return;
          final t = Curves.easeOutCubic.transform(_winCountController.value);
          setState(() => _overlayAnimatedWin = (_overlayTargetWin * t).round());
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
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_routeObserverSubscribed) {
      final route = ModalRoute.of(context);
      if (route != null) {
        appRouteObserver.subscribe(this, route);
        _routeObserverSubscribed = true;
      }
    }
  }

  @override
  void didPopNext() {
    if (mounted) setState(() => _lastWinAmount = 0);
  }

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    _adjustTimer?.cancel();
    _loseOverlayTimer?.cancel();
    _winOverlayTimer?.cancel();
    _adjustWatch?.stop();
    BalanceService.balanceNotifier.removeListener(_onBalanceNotifierChanged);
    _adjustTimer?.cancel();
    _roomMoveController.dispose();
    _dropController.dispose();
    _balanceCountController.dispose();
    _sinkController.dispose();
    _failPhysicsTicker?.dispose();
    _losePanelController.dispose();
    _winFadeController.dispose();
    _winCountController.dispose();
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

  double _screenScale(BuildContext context) => _gameLayoutScale;

  String _formatAmount(int value) {
    final s = value.toString();
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write(' ');
      b.write(s[i]);
    }
    return b.toString();
  }

  /// Как в chief_trolls / gold_vein — точки между тысячами
  String _formatWinAmount(int value) {
    final s = value.toString();
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
      b.write(s[i]);
    }
    return b.toString();
  }

  Widget _buildOutlinedValue(String value, {double size = 18.58, double? letterSpacing}) {
    TextStyle valueTextStyle({Color? color, Paint? foreground}) {
      return TextStyle(
        fontFamily: 'Gotham',
        color: foreground == null ? color : null,
        foreground: foreground,
        fontSize: size,
        fontWeight: FontWeight.w900,
        fontStyle: FontStyle.normal,
        height: 1.6,
        letterSpacing: letterSpacing ?? -0.02 * size,
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
    final floorIndex = _placedRooms.length;
    return _baseMultiplierForFloor(floorIndex);
  }

  _RoomAsset _pickNextRoom() {
    _activeRoomBonusType = 0;
    final floorIndex = _placedRooms.length;
    final seqIndex = floorIndex % _roomSequence.length;
    return _roomCatalog[_roomSequence[seqIndex]];
  }

  Size _scaledRoomSize(_RoomAsset room, double scale) {
    return Size(
      room.sourceSize.width * scale * _towerVisualScale * _roomsAndFoundationScale,
      room.sourceSize.height * scale * _towerVisualScale * _roomsAndFoundationScale,
    );
  }

  double _towerScaled(double value, double scale) {
    return value * scale * _towerVisualScale;
  }

  double _fieldCenterX(double scale) => (_fieldWidth * scale) / 2;

  double _foundationTop(double scale) {
    final fieldH = _fieldHeight * scale;
    final foundationH = _towerScaled(_foundationHeight, scale) * _roomsAndFoundationScale;
    final foundationBottom = _foundationBottom * scale;
    return fieldH - foundationBottom - foundationH;
  }

  double _foundationSurfaceY(double scale) {
    return _foundationTop(scale) +
        _towerScaled(_foundationSurfaceInsetTop, scale) * _roomsAndFoundationScale;
  }

  double _swingProgress() {
    if (_floorsRequired <= 1) return 1;
    return (_placedRooms.length / (_floorsRequired - 1)).clamp(0.0, 1.0);
  }

  int _currentSwingDurationMs() {
    final progress = _swingProgress();
    // Быстрее с этапа 3+: степенная кривая
    final p = pow(progress, 0.75).toDouble();
    final duration =
        _roomMoveBaseDurationMs -
        ((_roomMoveBaseDurationMs - _roomMoveMinDurationMs) * p).round();
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

  double _currentSwingAngle() {
    final t = Curves.easeInOutSine.transform(_roomMoveController.value);
    return ((t * 2) - 1) * _hookSwingMaxAngleRad;
  }

  double _currentSwingCenterX(_RoomAsset room, double scale) {
    final angle = _currentSwingAngle();
    final roomSize = _scaledRoomSize(room, scale);
    final roomOffsetY = room.placeOffsetY * scale;
    final roomTop = _towerScaled(_roomSpawnTop, scale) + roomOffsetY;
    final pivotY = _towerScaled(_hookTop, scale);
    final armLength = (roomTop + roomSize.height / 2) - pivotY;
    return _fieldCenterX(scale) + armLength * sin(angle);
  }

  double _activeRoomTopLocal(_RoomAsset room, double scale) {
    final hookTop = _towerScaled(_hookTop, scale);
    final trossH = _towerScaled(_trossHeight, scale);
    final trossDownOffset = _trossDownOffset * scale;
    final roomOffsetY = room.placeOffsetY * scale;
    final roomTop = _towerScaled(_roomSpawnTop, scale) + roomOffsetY;
    final trossTop = max(0.0, roomTop - hookTop - trossH - trossDownOffset);
    return trossTop + trossH + trossDownOffset - (_roomHookOffsetUp * scale)
        + _roomOffsetDownOnHook;
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

  /// Плавный адаптив: scale 0.82–0.92 → 20px, scale 1.28+ → 40px (1520×1080 и др.).
  double _firstRoomLandingExtraDown(double scale) {
    const base = 20.0;
    const scaleRef = 0.92;
    const scaleHigh = 1.28;
    const extraAtHigh = 20.0;
    if (scale <= scaleRef) return base;
    final t = ((scale - scaleRef) / (scaleHigh - scaleRef)).clamp(0.0, 1.0);
    return base + t * extraAtHigh;
  }

  /// Измеренная позиция поверхности фундамента (в координатах поля). Fallback — вычисленная.
  double? _measuredFoundationSurfaceY(double scale) {
    final foundationBox =
        _foundationKey.currentContext?.findRenderObject() as RenderBox?;
    final fieldBox =
        _fieldKey.currentContext?.findRenderObject() as RenderBox?;
    if (foundationBox == null || fieldBox == null) return null;
    final foundationTopInField =
        fieldBox.globalToLocal(foundationBox.localToGlobal(Offset.zero)).dy;
    return foundationTopInField +
        _towerScaled(_foundationSurfaceInsetTop, scale) * _roomsAndFoundationScale;
  }

  Offset _roomTargetTopLeft(_RoomAsset room, double leftX, double scale) {
    final roomSize = _scaledRoomSize(room, scale);
    final targetVisibleBottomY = _placedRooms.isEmpty
        ? (_measuredFoundationSurfaceY(scale) ?? _foundationSurfaceY(scale)) -
            (_foundationLandingLift * scale) +
            (_firstRoomLandingExtraDown(scale) - 30) * scale +
            70 * scale
        : _roomVisibleTopY(
                _restingPlacedRoomTop(_placedRooms.length - 1, scale),
                scale,
              ) +
              (_stackLandingExtraDown * scale);
    final renderedTop =
        targetVisibleBottomY - _roomVisibleBottomOffset(roomSize, scale);
    final roomOffsetY = room.placeOffsetY * scale;
    return Offset(leftX, renderedTop + roomOffsetY);
  }

  Offset _activeRoomTopLeft(_RoomAsset room, double scale) {
    final roomSize = _scaledRoomSize(room, scale);
    final theta = _currentSwingAngle();
    final L = _activeRoomTopLocal(room, scale) + _roomOnlyOffsetDown;
    final cx = _fieldCenterX(scale);
    final hy = _towerScaled(_hookTop, scale);
    final w = roomSize.width;
    final cosT = cos(theta);
    final sinT = sin(theta);
    // Пивот у верха троса; в локальных координатах до поворота верхний левый угол комнаты = (-w/2, L)
    final wx = -0.5 * w * cosT + L * sinT;
    final wy = 0.5 * w * sinT + L * cosT;
    return Offset(cx + wx, hy + wy);
  }

  /// Реальный левый верх комнаты на крюке в координатах поля (как на экране).
  Offset? _measuredHangingRoomTopLeftInField() {
    final rb = _hangingRoomKey.currentContext?.findRenderObject() as RenderBox?;
    final fb = _fieldKey.currentContext?.findRenderObject() as RenderBox?;
    if (rb == null || fb == null || !rb.hasSize) return null;
    final topLeft = rb.localToGlobal(Offset.zero);
    return fb.globalToLocal(topLeft);
  }

  /// Неподвижные AABB башни + фундамента (как на экране)
  List<Rect> _towerStaticCollisionRects(double scale) {
    final fieldH = _fieldHeight * scale;
    final fieldW = _fieldWidth * scale;
    final totalSink = _totalSinkOffset(scale);
    final fw =
        _towerScaled(_foundationWidth, scale) * _roomsAndFoundationScale;
    final fh =
        _towerScaled(_foundationHeight, scale) * _roomsAndFoundationScale;
    final left = (fieldW - fw) / 2;
    final bottomPad = _foundationBottom * scale - totalSink;
    final topY = fieldH - bottomPad - fh;
    final insetF = min(_failTowerCollisionTopInset * scale, fh * 0.38);
    final fhCol = max(22.0 * scale, fh - insetF);
    final fwCol = fw * _towerCollisionWidthFactor;
    final leftCol = left + (fw - fwCol) / 2;
    final list = <Rect>[Rect.fromLTWH(leftCol, topY + insetF, fwCol, fhCol)];
    for (var i = 0; i < _placedRooms.length; i++) {
      final pr = _placedRooms[i];
      final ts = _totalSinkOffset(scale);
      final pref = _sinkPrefix(i) * scale;
      final dy = ts - pref;
      final inset =
          min(_failTowerCollisionTopInset * scale, pr.size.height * 0.4);
      final rh = max(18.0 * scale, pr.size.height - inset);
      final rwCol = pr.size.width * _towerCollisionWidthFactor;
      final rxCol = pr.topLeft.dx + (pr.size.width - rwCol) / 2;
      list.add(Rect.fromLTWH(
        rxCol,
        pr.topLeft.dy + dy + inset,
        rwCol,
        rh,
      ));
    }
    return list;
  }

  bool _failResolveAgainstBlock(Rect s, double scale) {
    final L = _failPx;
    final T = _failPy;
    final w = _failPhysW;
    final h = _failPhysH;
    final R = L + w;
    final B = T + h;
    final ox = min(R, s.right) - max(L, s.left);
    final oy = min(B, s.bottom) - max(T, s.top);
    if (ox < 0.5 || oy < 0.5) return false;

    if (ox < oy) {
      final cx = L + w / 2;
      if (cx < s.left + s.width / 2) {
        _failPx = s.left - w - 0.5;
      } else {
        _failPx = s.right + 0.5;
      }
      _failVx = -_failVx * _failWallBounce;
      if (_failVx.abs() < 22) _failVx = 0;
      _failVy *= 0.84;
      // Закрутка только при «скользящем» ударе уголком (глубина по Y сопоставима с ox)
      final sideSign = cx < s.left + s.width / 2 ? -1.0 : 1.0;
      final cornerScrape = oy > ox * 0.45 && oy < ox * 2.6;
      if (cornerScrape) {
        final spin = min(
          _failAngCornerMax * scale,
          2.2 * scale + min(_failVy.abs() / 520, 2.4) * scale,
        );
        _failOmegaRadPerSec += sideSign * spin;
      }
    } else {
      final cy = T + h / 2;
      final mid = s.top + s.height / 2;
      if (cy < mid) {
        // Не цепляемся за верхнюю кромку AABB в воздухе — ждём реального провала ниже крыши
        if (_failVy > 0 && B < s.top + _failLandMinPenetration * scale) {
          return false;
        }
        _failPy = s.top - h - 0.5;
        if (_failVy > 0) {
          _failVy = -_failVy * _failBlockBounce;
          final cx = L + w / 2;
          final kick = 140.0 * scale;
          final topSign = cx < s.left + s.width / 2 ? -1.0 : 1.0;
          _failVx += topSign * kick;
          // Угол крыши: закрутка только если приземление у края блока
          final distToEdge = min(cx - s.left, s.right - cx);
          if (distToEdge < 24 * scale) {
            final spin = (cx < s.left + s.width / 2 ? -1.0 : 1.0) *
                min(_failAngCornerMax * 0.65 * scale, 3.2 * scale);
            _failOmegaRadPerSec += spin;
          }
        }
      } else {
        _failPy = s.bottom + 0.5;
        if (_failVy < 0) _failVy = -_failVy * _failBlockBounce;
        final ox2 = ox;
        final oy2 = oy;
        if (ox2 > oy2 * 0.5 && ox2 < oy2 * 2.2) {
          _failOmegaRadPerSec +=
              (_failVx.sign.clamp(-1.0, 1.0)) * 2.0 * scale;
        }
      }
      _failVx *= 0.87;
    }
    return true;
  }

  void _failPhysicsTick(double scale) {
    if (!_failPhysActive) return;
    const dt = 1 / 60.0;
    _failPhysTicks++;
    final g = _failGravity * scale;
    final fieldH = _fieldHeight * scale;

    _failVy = (_failVy + g * dt).clamp(-2200 * scale, 3000 * scale);
    _failPx += _failVx * dt;
    _failPy += _failVy * dt;
    _failVx *= _failAirVxDamp;
    _failOmegaRadPerSec *= _failOmegaDamp;
    _failOmegaRadPerSec =
        _failOmegaRadPerSec.clamp(-7.0 * scale, 7.0 * scale);
    _failAngleRad += _failOmegaRadPerSec * dt;

    final blocks = _towerStaticCollisionRects(scale);
    if (_failPhysTicks > _failPhysCollisionDelayTicks) {
      for (var iter = 0; iter < 6; iter++) {
        for (final b in blocks) {
          _failResolveAgainstBlock(b, scale);
        }
      }
    }

    final spd = sqrt(_failVx * _failVx + _failVy * _failVy);
    if (_failPhysTicks > 320 && spd < 38 * scale) {
      _failVx += (_crashDirection >= 0 ? 1.0 : -1.0) * 240 * scale;
      _failVy -= 140 * scale;
    }

    if (_failPy > fieldH + 130 * scale || _failPhysTicks > 980) {
      _failPhysActive = false;
      _failPhysicsTicker?.dispose();
      _failPhysicsTicker = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _onFailFallAnimationComplete();
      });
    }
  }

  bool get _isBuildLocked =>
      _loadingBalance ||
      _isDropping ||
      _sinkController.isAnimating ||
      _failPhysActive ||
      _isFailing ||
      _isWinning;

  void _resetRoundState({bool keepOutcome = false}) {
    _loseOverlayTimer?.cancel();
    _winOverlayTimer?.cancel();
    _stopContinuousBetAdjust();
    _sinkController.reset();
    _failPhysicsTicker?.dispose();
    _failPhysicsTicker = null;
    _failPhysActive = false;
    _losePanelController.reset();
    _winFadeController.reset();
      setState(() {
      _placedRooms.clear();
      _roundActive = false;
      _isDropping = false;
      _droppingRoom = null;
      _droppingRoomBonusType = null;
      _dropFrom = null;
      _dropTo = null;
      _dropWillSucceed = false;
      _crashDirection = 1;
      _failPhysRoom = null;
      _failAngleRad = 0;
      _failOmegaRadPerSec = 0;
      _currentRoundWinAmount = 0;
      _lastWinAmount = 0;
      _activeRoom = _pickNextRoom();
      _activeRoomBonusType = null;
      if (!keepOutcome) {
        _isFailing = false;
        _isWinning = false;
      }
    });
    _restartSwingAnimation();
  }

  void _dismissWinOverlay() {
    if (!_isWinning) return;
    _winOverlayTimer?.cancel();
    _collectWinTransitionPending = false;
    unawaited(BalanceService.setBalance(_balance));
    _resetRoundState();
  }

  void _onCollectButtonTap() {
    if (_isDropping ||
        _sinkController.isAnimating ||
        _failPhysActive ||
        _placedRooms.isEmpty) {
      return;
    }
    if (_isWinning) return;
    if (_collectWinTransitionPending) return;
    _collectWinTransitionPending = true;
    HapticFeedback.lightImpact();
    _winOverlayTimer?.cancel();
    _winFadeController.stop();
    _winCountController.stop();
    _overlayTargetWin = _currentRoundWinAmount;
    _overlayAnimatedWin = 0;
      setState(() {
      _roundActive = false;
      _isWinning = true;
      _lastWinAmount = _currentRoundWinAmount;
      _balance += _currentRoundWinAmount;
      _activeRoom = null;
    });
    _animateBalanceChange(durationMs: 620);
    unawaited(BalanceService.setBalance(_balance));
    _winFadeController.forward(from: 0);
    _winCountController.forward(from: 0);
    unawaited(AudioService.instance.playWin());
    _roomMoveController.stop();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _collectWinTransitionPending = false;
    });
    _winOverlayTimer = Timer(const Duration(milliseconds: 2800), () {
      if (!mounted) return;
      _dismissWinOverlay();
      });
  }

  void _onFailFallAnimationComplete() {
      if (!mounted) return;
    _loseOverlayTimer?.cancel();
      setState(() {
      _placedRooms.clear();
      _failPhysRoom = null;
      _failAngleRad = 0;
      _failOmegaRadPerSec = 0;
      _isFailing = true;
      _activeRoom = null;
      _activeRoomBonusType = null;
    });
    unawaited(AudioService.instance.playLose());
    _losePanelController.forward(from: 0);
    _loseOverlayTimer = Timer(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      _retryAfterLose();
    });
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

    if (!mounted || _activeRoom != room) return;
    final scale = _screenScale(context);
    // Позиция с экрана: inner Transform(-angle) держит дом вертикально — формула top-left не совпадает.
    final from = _measuredHangingRoomTopLeftInField() ??
        _activeRoomTopLeft(room, scale);
    _roomMoveController.stop();
    await _doDropRoom(room, from, scale);
  }

  Future<void> _doDropRoom(_RoomAsset room, Offset from, double scale) async {
    if (!mounted || _activeRoom != room) return;
    final roomSize = _scaledRoomSize(room, scale);
    final roomLeft = from.dx;
    final roomRight = from.dx + roomSize.width;
    final currentCenter = from.dx + roomSize.width / 2;
    final fieldW = _fieldWidth * scale;
    final margin = _loseZoneMargin * scale;
    final inBounds =
        from.dx >= margin && (from.dx + roomSize.width) <= (fieldW - margin);
    final supportLeft = _placedRooms.isEmpty
        ? ((_fieldWidth * scale) -
                  (_towerScaled(_foundationWidth, scale) *
                      _roomsAndFoundationScale)) /
              2
        : _placedRooms.last.topLeft.dx;
    final supportRight = _placedRooms.isEmpty
        ? supportLeft +
              (_towerScaled(_foundationWidth, scale) *
                  _roomsAndFoundationScale)
        : _placedRooms.last.topLeft.dx + _placedRooms.last.size.width;
    final overlap = min(roomRight, supportRight) - max(roomLeft, supportLeft);
    final requiredOverlap = min(roomSize.width, supportRight - supportLeft) * _requiredOverlapFactor;
    final success =
        inBounds &&
        overlap >= requiredOverlap;
    final supportCenter = (supportLeft + supportRight) / 2;
    final failDirection = currentCenter >= supportCenter ? 1.0 : -1.0;

    if (!success) {
    setState(() {
        if (_placedRooms.isEmpty) _balance -= _bet;
        _roundActive = false;
        _isDropping = false;
        _isFailing = false;
        _droppingRoom = null;
        _dropFrom = null;
        _dropTo = null;
        _dropWillSucceed = false;
        _activeRoom = null;
        _activeRoomBonusType = null;
        _crashDirection = failDirection;
        _failPhysRoom = room;
        final pw = roomSize.width * _failPhysBodyScale;
        final ph = roomSize.height * _failPhysBodyScale;
        // Тело внизу комнаты (ноги) — меньше зацепов о бока, старт без сдвига картинки
        _failPx = from.dx + roomSize.width / 2 - pw / 2;
        _failPy = from.dy + roomSize.height - ph;
        _failVx = 0;
        _failVy = 380 * scale;
        _failPhysW = pw;
        _failPhysH = ph;
        _failPhysTicks = 0;
        _failAngleRad = 0;
        _failOmegaRadPerSec = 0;
      });
      _animateBalanceChange(durationMs: 360);
      await BalanceService.setBalance(_balance);
      _roomMoveController.stop();
      _loseOverlayTimer?.cancel();
      _losePanelController.reset();
      _failPhysicsTicker?.dispose();
      _failPhysActive = true;
      final failSimScale = scale;
      _failPhysicsTicker = createTicker((_) {
        if (!mounted || !_failPhysActive) return;
        _failPhysicsTick(failSimScale);
        setState(() {});
      });
      _failPhysicsTicker!.start();
      unawaited(AnalyticsService.reportGameLoss(_gameName));
    HapticFeedback.lightImpact();
      return;
  }

    final to = _roomTargetTopLeft(room, from.dx, scale);

    setState(() {
      if (_placedRooms.isEmpty) _balance -= _bet;
      _isDropping = true;
      _isFailing = false;
      _droppingRoom = room;
      _droppingRoomBonusType = _activeRoomBonusType;
      _dropFrom = from;
      _dropTo = to;
      _dropWillSucceed = true;
      _crashDirection = failDirection;
      _activeRoom = null;
      _activeRoomBonusType = null;
    });
    _animateBalanceChange(durationMs: 360);
    await BalanceService.setBalance(_balance);
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
      final multiplier = _baseMultiplierForFloor(floorIndex);
      final roomSize = _scaledRoomSize(room, _screenScale(context));
      final centerX = target.dx + roomSize.width / 2;
      final win = (_bet * multiplier).ceil();
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
        // Баланс пополняется только при Collect, не при каждой комнате
        _currentRoundWinAmount += win;
        _droppingRoom = null;
        _dropFrom = null;
        _dropTo = null;
        _isDropping = false;
      });
      // Баланс пополняется только при Collect/победе, не при каждой комнате
      unawaited(AudioService.instance.playMineDepthTowerRoomDown());
      unawaited(AnalyticsService.reportGameWin(_gameName));
      _dropController.reset();
      final sinkFuture = _sinkController.forward(from: 0);

      sinkFuture.whenCompleteOrCancel(() {
        if (!mounted) return;
        if (completedTower) {
          _winOverlayTimer?.cancel();
          _winFadeController.stop();
          _winCountController.stop();
          setState(() {
            _roundActive = false;
            _isWinning = true;
            _lastWinAmount = _currentRoundWinAmount;
            _balance += _currentRoundWinAmount; // пополняем при победе
            _activeRoom = null;
            _overlayTargetWin = _currentRoundWinAmount;
            _overlayAnimatedWin = 0;
          });
          _animateBalanceChange(durationMs: 620);
          _winFadeController.forward(from: 0);
          _winCountController.forward(from: 0);
          unawaited(AudioService.instance.playWin());
          _roomMoveController.stop();
          _winOverlayTimer = Timer(const Duration(milliseconds: 2800), () {
            if (!mounted) return;
            _dismissWinOverlay();
          });
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
      key: _fieldKey,
      width: fieldW,
      height: fieldH,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: (fieldW - foundationW * _roomsAndFoundationScale) / 2,
            bottom: (_foundationBottom * scale) - totalSink,
            child: SizedBox(
              key: _foundationKey,
              width: foundationW * _roomsAndFoundationScale,
              height: foundationH * _roomsAndFoundationScale,
              child: Image.asset(
                'assets/images/mine_depth_tower/foundation.png',
                fit: BoxFit.fill,
              ),
            ),
          ),
          if (_failPhysRoom != null) _buildFailPhysRoom(scale),
          for (final room in _placedRooms) _buildPlacedRoom(room, scale),
          if (_activeRoom != null && !_isDropping) _buildHangingRig(scale),
          if (_droppingRoom != null &&
              _dropFrom != null &&
              _dropTo != null)
            _buildDroppingRoom(scale),
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

  static const _roomHookOffsetUp = 20.0;

  Widget _buildHangingRig(double scale) {
    final room = _activeRoom!;
    final roomSize = _scaledRoomSize(room, scale);
    final hookTop = _towerScaled(_hookTop, scale);
    final hookW = _towerScaled(_hookWidth, scale);
    final hookH = _towerScaled(_hookHeight, scale);
    final trossW = _towerScaled(_trossWidth, scale);
    final trossH = _towerScaled(_trossHeight, scale);
    final trossDownOffset = _trossDownOffset * scale;
    final roomTopLocal = _activeRoomTopLocal(room, scale);
    final roomTopForRoom = roomTopLocal + _roomOnlyOffsetDown;
    final trossTop = roomTopLocal - trossH - trossDownOffset + (_roomHookOffsetUp * scale)
        - _trossOffsetUp;
    final pivotX = _fieldCenterX(scale);
    final rigWidth = max(max(hookW, trossW), roomSize.width);

    return Positioned(
      left: pivotX - rigWidth / 2,
      top: hookTop,
        child: AnimatedBuilder(
        animation: _roomMoveController,
          builder: (context, child) {
          final angle = _currentSwingAngle();
          return Transform.rotate(
            angle: angle,
            alignment: Alignment.topCenter,
          child: SizedBox(
              width: rigWidth,
              height: roomTopForRoom + roomSize.height,
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
                    child: Transform.rotate(
                      angle: -angle,
                      alignment: Alignment.topCenter,
                      child: SizedBox(
                        width: trossW,
                        height: trossH,
                        child: Image.asset(
                          'assets/images/mine_depth_tower/tross.png',
                          fit: BoxFit.fill,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: roomTopForRoom,
                    left: (rigWidth - roomSize.width) / 2,
                    child: Transform.rotate(
                      key: _hangingRoomKey,
                      angle: -angle,
                      alignment: Alignment.topCenter,
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
                      ),
                    ],
                  ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFailPhysRoom(double scale) {
    final room = _failPhysRoom!;
    final vis = _scaledRoomSize(room, scale);
    // Картинка полного размера; AABB физики — нижняя половина по центру
    return Positioned(
      left: _failPx + _failPhysW / 2 - vis.width / 2,
      top: _failPy + _failPhysH - vis.height,
      child: Transform.rotate(
        angle: _failAngleRad,
        alignment: Alignment.bottomCenter,
                        child: SizedBox(
          width: vis.width,
          height: vis.height,
                          child: Image.asset(
            room.asset,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                          ),
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
        return Positioned(left: dx, top: dy, child: child!);
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
              left: 0,
              right: 0,
              bottom: _collectBottomOffset(scale),
              child: Center(child: _buildCollectButton(scale)),
            ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 18 * scale),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _buildBetControl(scale),
                SizedBox(width: 16 * scale),
                Transform.translate(
                  offset: Offset(0, 10 * scale), // +15 px вниз только кнопка Start/Build
                  child: IgnorePointer(
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
      onTap: _onCollectButtonTap,
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

  /// Как jackpot-победа в Gold Vein: YOU WIN! + жёлтая полоса с суммой
  Widget _buildWinOverlay(BuildContext context, double scale) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final bannerWidth = _fieldWidth * scale;
    final smallTitle = 33.8 * scale;
    final amountSize = 51.52 * scale;
    final amountText = _formatWinAmount(_overlayAnimatedWin);

    Widget outlinedText(String text, double size, {double? stroke}) {
      final strokeWidth = stroke ?? (size * 0.046);
      final insetShadow = Shadow(
        color: const Color(0x40000000),
        offset: Offset(0, 4.83 * scale),
        blurRadius: 0,
      );
          return Stack(
        alignment: Alignment.center,
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

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
                  children: [
          SizedBox(
            width: bannerWidth,
            child: Center(child: outlinedText('YOU WIN!', smallTitle)),
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
                    amountSize,
                    stroke: 2.41 * scale,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(height: 4 * scale),
          SizedBox(
            width: bannerWidth,
            child: Center(child: outlinedText('YOU WIN!', smallTitle)),
          ),
        ],
      ),
    );
  }

  Widget _buildLoseContent(double scale) {
    final fade = CurvedAnimation(
      parent: _losePanelController,
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
            SizedBox(height: 18 * scale),
                  ],
                ),
              ),
    );
  }

  Widget _buildWinOverlayFade(double scale) {
    final fade = CurvedAnimation(
      parent: _winFadeController,
      curve: Curves.easeOutCubic,
    );
    return FadeTransition(
      opacity: fade,
      child: Positioned.fill(
        child: SafeArea(
          child: Stack(
            children: [
                Positioned.fill(
                  child: GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    _dismissWinOverlay();
                  },
                    behavior: HitTestBehavior.opaque,
                  child: Container(color: const Color(0x66000000)),
                ),
              ),
              _buildMultiplierPlate(scale),
                        Center(
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.94, end: 1).animate(
                    CurvedAnimation(
                      parent: _winFadeController,
                      curve: Curves.easeOutCubic,
                    ),
                  ),
                  child: _buildWinOverlay(context, scale),
                          ),
                        ),
                        Positioned(
                top: 4 * scale,
                          left: 0,
                          right: 0,
                child: _buildTopBar(scale),
              ),
            ],
                              ),
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
          _gameLayoutScale = min(
            constraints.maxWidth / 390,
            constraints.maxHeight / 844,
          ).clamp(0.82, 1.3);
          final scale = _gameLayoutScale;
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
              else ...[
                _buildGameContent(scale),
                if (_isWinning) _buildWinOverlayFade(scale),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _RoomAsset {
  const _RoomAsset({
    required this.asset,
    required this.sourceSize,
    this.placeOffsetY = 0,
  });

  final String asset;
  final Size sourceSize;
  final double placeOffsetY;
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
