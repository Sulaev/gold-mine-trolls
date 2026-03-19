import 'dart:async';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:gold_mine_trolls/services/settings_service.dart';

/// Global audio: bg music (loop + fade at end), button click, game-specific SFX.
/// All players use just_audio so they share the same session and mix correctly.
class AudioService {
  AudioService._();

  static final AudioService _instance = AudioService._();
  static AudioService get instance => _instance;

  static const _bgAsset = 'assets/sounds/common/bg-sound.mp3';
  static const _clickAsset = 'assets/sounds/common/button_click.wav';
  static const _rouletteSpinAsset = 'assets/sounds/gold_vein/roulette_spin.wav';
  static const _wheelSpinAsset =
      'assets/sounds/miners_wheel_of_fortune/gumball-machine.wav';
  static const _drillingAsset = 'assets/sounds/mine_depth_tower/drilling.wav';
  static const _mineDepthTowerRoomDownAsset =
      'assets/sounds/mine_depth_tower/room_down.wav';
  static const _loseAsset = 'assets/sounds/lose/lose.wav';
  static const _winAsset = 'assets/sounds/winning/win.wav';
  static const _cardDropAsset = 'assets/sounds/card_mine_21/card_drop.wav';
  static const _goldenAvalancheCoinAsset =
      'assets/sounds/golden_avalanche/coin.wav';
  static const _goldenAvalanchePegClickAsset =
      'assets/sounds/golden_avalanche/click.wav';
  /// Few preloaded players (not 10× ExoPlayer); round-robin for overlap.
  static const _goldenAvalanchePegPlayerCount = 5;
  static const _treasureTrailLadderClaimAsset =
      'assets/sounds/treasure_trail_ladder/claim.wav';
  static const _chiefTrollsWheelSpinAsset =
      'assets/sounds/chief_trolls_wheel/wheel_sound.wav';
  static const _cautiousMinerBoomAsset =
      'assets/sounds/cautious_miner/boom.wav';

  static const _bgFadeStartBeforeEndSec = 4.0;
  static const _bgDuckedVolume = 0.25;
  static const _bgVolume = 0.4;

  final AudioPlayer _bgPlayer = AudioPlayer();
  final AudioPlayer _clickPlayer = AudioPlayer();
  final AudioPlayer _sfxPlayer = AudioPlayer();
  final AudioPlayer _drillingPlayer = AudioPlayer();
  final AudioPlayer _mineDepthTowerRoomDownPlayer = AudioPlayer();
  final AudioPlayer _cardDropPlayer = AudioPlayer();
  final AudioPlayer _losePlayer = AudioPlayer();
  final AudioPlayer _winPlayer = AudioPlayer();
  final AudioPlayer _goldenAvalancheCoinPlayer = AudioPlayer();
  final List<AudioPlayer> _gaPegPlayers = List.generate(
    _goldenAvalanchePegPlayerCount,
    (_) => AudioPlayer(),
  );
  int _gaPegRoundRobin = 0;
  bool _gaPegPreloaded = false;
  Future<void>? _gaPegPreloadFuture;
  final AudioPlayer _treasureTrailLadderClaimPlayer = AudioPlayer();
  final AudioPlayer _cautiousMinerBoomPlayer = AudioPlayer();
  final AudioPlayer _minersWheelSpinPlayer = AudioPlayer();
  final AudioPlayer _rouletteSpinPlayer = AudioPlayer();

  StreamSubscription<Duration>? _bgPositionSub;
  StreamSubscription<PlayerState>? _bgStateSub;
  Timer? _bgSpeedGuardTimer;
  bool _bgInitialized = false;
  bool _bgStarted = false;
  bool _cardDropLoaded = false;
  bool _drillingLoaded = false;
  bool _mineDepthTowerRoomDownLoaded = false;
  bool _goldenAvalancheCoinLoaded = false;
  bool _treasureTrailLadderClaimLoaded = false;
  bool _cautiousMinerBoomLoaded = false;
  bool _clickLoaded = false;
  bool _loseLoaded = false;
  bool _winLoaded = false;
  bool _minersWheelSpinLoaded = false;
  bool _rouletteSpinLoaded = false;
  double _bgVolumeBeforeDuck = 1.0;
  Timer? _rouletteSpinFadeTimer;

  Future<void> preloadAssets() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(
        AudioSessionConfiguration.music().copyWith(
          avAudioSessionCategoryOptions:
              AVAudioSessionCategoryOptions.mixWithOthers,
          androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
        ),
      );

      await _preloadGoldenAvalanchePegClicks();

      if (!_bgInitialized) {
        await _bgPlayer.setAsset(_bgAsset);
        await _bgPlayer.setLoopMode(LoopMode.one);
        await _bgPlayer.setVolume(_bgVolume);
        await _bgPlayer.setSpeed(1.0);
        _bgInitialized = true;
      }

      if (!_clickLoaded) {
        await _clickPlayer.setAsset(_clickAsset);
        _clickLoaded = true;
      }
      if (!_cardDropLoaded) {
        await _cardDropPlayer.setAsset(_cardDropAsset);
        _cardDropLoaded = true;
      }
      if (!_drillingLoaded) {
        await _drillingPlayer.setAsset(_drillingAsset);
        _drillingLoaded = true;
      }
      if (!_mineDepthTowerRoomDownLoaded) {
        await _mineDepthTowerRoomDownPlayer.setAsset(
          _mineDepthTowerRoomDownAsset,
        );
        _mineDepthTowerRoomDownLoaded = true;
      }
      if (!_goldenAvalancheCoinLoaded) {
        await _goldenAvalancheCoinPlayer.setAsset(_goldenAvalancheCoinAsset);
        _goldenAvalancheCoinLoaded = true;
      }
      if (!_treasureTrailLadderClaimLoaded) {
        await _treasureTrailLadderClaimPlayer.setAsset(
          _treasureTrailLadderClaimAsset,
        );
        _treasureTrailLadderClaimLoaded = true;
      }
      if (!_cautiousMinerBoomLoaded) {
        await _cautiousMinerBoomPlayer.setAsset(_cautiousMinerBoomAsset);
        _cautiousMinerBoomLoaded = true;
      }
      if (!_loseLoaded) {
        await _losePlayer.setAsset(_loseAsset);
        _loseLoaded = true;
      }
      if (!_winLoaded) {
        await _winPlayer.setAsset(_winAsset);
        _winLoaded = true;
      }
      if (!_minersWheelSpinLoaded) {
        await _minersWheelSpinPlayer.setAsset(_wheelSpinAsset);
        _minersWheelSpinLoaded = true;
      }
      if (!_rouletteSpinLoaded) {
        await _rouletteSpinPlayer.setAsset(_rouletteSpinAsset);
        _rouletteSpinLoaded = true;
      }

      // Warm bundle cache for shared SFX assets that reuse one player instance.
      await rootBundle.load(_chiefTrollsWheelSpinAsset);
    } catch (_) {}
  }

  Future<void> _ensureBgSpeedCorrect() async {
    if (!_bgInitialized) return;
    try {
      await _bgPlayer.setSpeed(1.0);
    } catch (_) {}
  }

  /// Call when app resumes from background. Fixes playback speed corruption.
  void onAppResumed() {
    unawaited(_ensureBgSpeedCorrect());
    Future.delayed(const Duration(milliseconds: 300), _ensureBgSpeedCorrect);
  }

  /// Start background music (loop with fade at end). Call once at app start.
  Future<void> startBgMusic() async {
    if (_bgStarted) return;
    if (!SettingsService.musicEnabled) return;
    try {
      await preloadAssets();
      _bgStarted = true;

      final duration = _bgPlayer.duration ?? Duration.zero;
      if (duration.inSeconds < _bgFadeStartBeforeEndSec) return;

      _bgPositionSub = _bgPlayer.positionStream.listen((pos) async {
        final dur = _bgPlayer.duration ?? Duration.zero;
        if (dur.inSeconds < _bgFadeStartBeforeEndSec) return;
        final fadeStart =
            dur - const Duration(seconds: _bgFadeStartBeforeEndSec ~/ 1);
        if (pos >= fadeStart) {
          final t =
              (pos.inMilliseconds - fadeStart.inMilliseconds) /
              (dur.inMilliseconds - fadeStart.inMilliseconds);
          final vol = (_bgVolume * (1.0 - t)).clamp(0.0, 1.0);
          await _bgPlayer.setVolume(vol);
        } else {
          await _bgPlayer.setVolume(_bgVolume);
        }
      });

      _bgStateSub = _bgPlayer.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.ready ||
            state.processingState == ProcessingState.completed) {
          unawaited(_ensureBgSpeedCorrect());
        }
      });

      _bgSpeedGuardTimer?.cancel();
      _bgSpeedGuardTimer = Timer.periodic(
        const Duration(seconds: 1),
        (_) => unawaited(_ensureBgSpeedCorrect()),
      );

      await _bgPlayer.play();
    } catch (_) {}
  }

  /// Stop background music.
  Future<void> stopBgMusic() async {
    _bgStarted = false;
    _bgPositionSub?.cancel();
    _bgPositionSub = null;
    _bgStateSub?.cancel();
    _bgStateSub = null;
    _bgSpeedGuardTimer?.cancel();
    _bgSpeedGuardTimer = null;
    await _bgPlayer.stop();
  }

  Future<void> setMusicEnabled(bool enabled) async {
    if (!enabled) {
      await stopBgMusic();
      return;
    }
    await startBgMusic();
  }

  Future<void> setSoundEnabled(bool enabled) async {
    if (enabled) return;
    try {
      _rouletteSpinFadeTimer?.cancel();
      _rouletteSpinFadeTimer = null;
      await _clickPlayer.stop();
      await _sfxPlayer.stop();
      await _drillingPlayer.stop();
      await _mineDepthTowerRoomDownPlayer.stop();
      await _cardDropPlayer.stop();
      await _losePlayer.stop();
      await _winPlayer.stop();
      await _goldenAvalancheCoinPlayer.stop();
      await _treasureTrailLadderClaimPlayer.stop();
      await _cautiousMinerBoomPlayer.stop();
      await _minersWheelSpinPlayer.stop();
      await _rouletteSpinPlayer.stop();
    } catch (_) {}
  }

  /// Play button click. Call on any button/banner tap.
  Future<void> playButtonClick() async {
    if (!SettingsService.soundEnabled) return;
    try {
      if (!_clickLoaded) {
        await _clickPlayer.setAsset(_clickAsset);
        _clickLoaded = true;
      }
      await _clickPlayer.stop();
      await _clickPlayer.setVolume(1.0);
      await _clickPlayer.seek(Duration.zero);
      await _clickPlayer.play();
      unawaited(_ensureBgSpeedCorrect());
    } catch (_) {}
  }

  /// Stop wheel spin sound. Call when ball animation ends.
  Future<void> stopWheelSpin() async {
    try {
      await _minersWheelSpinPlayer.stop();
    } catch (_) {}
  }

  /// Play Chief Trolls Wheel spin sound from the beginning.
  Future<void> playChiefTrollsWheelSpin(int durationMs) async {
    if (!SettingsService.soundEnabled) return;
    try {
      await _sfxPlayer.stop();
      await _sfxPlayer.setAsset(_chiefTrollsWheelSpinAsset);
      await _sfxPlayer.setVolume(1.0);
      await _sfxPlayer.seek(Duration.zero);
      await _sfxPlayer.play();
      unawaited(_ensureBgSpeedCorrect());
    } catch (_) {}
  }

  /// Stop and reset Chief Trolls Wheel spin sound.
  Future<void> stopChiefTrollsWheelSpin() async {
    try {
      await _sfxPlayer.stop();
      await _sfxPlayer.seek(Duration.zero);
      await _sfxPlayer.setVolume(1.0);
    } catch (_) {}
  }

  /// Ensure miners wheel spin asset is loaded. Call before playWheelSpin if needed.
  Future<void> ensureMinersWheelSpinLoaded() async {
    if (_minersWheelSpinLoaded) return;
    try {
      await _minersWheelSpinPlayer.setAsset(_wheelSpinAsset);
      _minersWheelSpinLoaded = true;
    } catch (_) {}
  }

  /// Play wheel spin (gumball_machine) and fade out over [durationMs].
  /// Call when miners wheel spin starts.
  /// Uses Timer.periodic for fade to avoid blocking UI on weak devices.
  /// Starts playback immediately without awaiting setup for instant response.
  Future<void> playWheelSpin(int durationMs) async {
    if (!SettingsService.soundEnabled) return;
    try {
      if (!_minersWheelSpinLoaded) {
        await ensureMinersWheelSpinLoaded();
      }
      unawaited(() async {
        await _minersWheelSpinPlayer.stop();
        await _minersWheelSpinPlayer.setVolume(1.0);
        await _minersWheelSpinPlayer.seek(Duration.zero);
        await _minersWheelSpinPlayer.play();
      }());

      final steps = 8;
      final stepMs = durationMs ~/ steps;
      var step = 0;
      Timer.periodic(Duration(milliseconds: stepMs), (t) {
        step++;
        if (step >= steps) {
          t.cancel();
          unawaited(_minersWheelSpinPlayer.stop());
          unawaited(_minersWheelSpinPlayer.seek(Duration.zero));
          unawaited(_ensureBgSpeedCorrect());
          return;
        }
        final vol = (1.0 - step / steps).clamp(0.0, 1.0);
        unawaited(_minersWheelSpinPlayer.setVolume(vol));
      });
    } catch (_) {}
  }

  /// Play card drop sound. Call when a card is dealt in Card Mine 21.
  /// Asset is loaded once and reused to avoid ExoPlayer init/release churn.
  Future<void> playCardDrop() async {
    if (!SettingsService.soundEnabled) return;
    try {
      if (!_cardDropLoaded) {
        await _cardDropPlayer.setAsset(_cardDropAsset);
        _cardDropLoaded = true;
      }
      await _cardDropPlayer.stop();
      await _cardDropPlayer.setVolume(1.8);
      await _cardDropPlayer.setSpeed(1.0);
      await _cardDropPlayer.seek(Duration.zero);
      await _cardDropPlayer.play();
      unawaited(_ensureBgSpeedCorrect());
    } catch (_) {}
  }

  void playGoldenAvalancheCoin() {
    if (!SettingsService.soundEnabled) return;
    unawaited(_playGoldenAvalancheCoinAsync());
  }

  Future<void> _playGoldenAvalancheCoinAsync() async {
    try {
      final p = _goldenAvalancheCoinPlayer;
      if (!_goldenAvalancheCoinLoaded) {
        await p.setAsset(_goldenAvalancheCoinAsset);
        _goldenAvalancheCoinLoaded = true;
      }
      await p.stop();
      await p.setVolume(1.0);
      await p.seek(Duration.zero);
      await p.play();
      unawaited(_ensureBgSpeedCorrect());
    } catch (_) {}
  }

  Future<void> _preloadGoldenAvalanchePegClicks() async {
    if (_gaPegPreloaded) return;
    _gaPegPreloadFuture ??= _doPreloadGoldenAvalanchePegClicks();
    try {
      await _gaPegPreloadFuture!;
    } finally {
      if (!_gaPegPreloaded) {
        _gaPegPreloadFuture = null;
      }
    }
  }

  Future<void> _doPreloadGoldenAvalanchePegClicks() async {
    try {
      for (final p in _gaPegPlayers) {
        await p.setAsset(_goldenAvalanchePegClickAsset);
        await p.setVolume(0.55);
      }
      _gaPegPreloaded = true;
    } catch (_) {
      _gaPegPreloaded = false;
    }
  }

  /// Ensures peg SFX buffers are ready (e.g. when opening Golden Avalanche).
  Future<void> warmUpGoldenAvalanchePegClicks() =>
      _preloadGoldenAvalanchePegClicks();

  void _playPegOnPlayer(AudioPlayer p) {
    unawaited(() async {
      try {
        await p.seek(Duration.zero);
        await p.play();
      } catch (_) {}
    }());
  }

  /// Ball hits peg — uses preloaded round-robin players (no soundpool / old embedding).
  void playGoldenAvalanchePegClick() {
    if (!SettingsService.soundEnabled) return;
    if (!_gaPegPreloaded) {
      unawaited(_pegClickAfterPreload());
      return;
    }
    final i = _gaPegRoundRobin % _gaPegPlayers.length;
    _gaPegRoundRobin++;
    _playPegOnPlayer(_gaPegPlayers[i]);
  }

  Future<void> _pegClickAfterPreload() async {
    await _preloadGoldenAvalanchePegClicks();
    if (!SettingsService.soundEnabled || !_gaPegPreloaded) return;
    final i = _gaPegRoundRobin % _gaPegPlayers.length;
    _gaPegRoundRobin++;
    _playPegOnPlayer(_gaPegPlayers[i]);
  }

  /// Play claim sound when correct card chosen in Treasure Trail Ladder.
  Future<void> playTreasureTrailLadderClaim() async {
    if (!SettingsService.soundEnabled) return;
    try {
      if (!_treasureTrailLadderClaimLoaded) {
        await _treasureTrailLadderClaimPlayer.setAsset(
          _treasureTrailLadderClaimAsset,
        );
        _treasureTrailLadderClaimLoaded = true;
      }
      await _treasureTrailLadderClaimPlayer.stop();
      await _treasureTrailLadderClaimPlayer.setVolume(1.0);
      await _treasureTrailLadderClaimPlayer.seek(Duration.zero);
      await _treasureTrailLadderClaimPlayer.play();
      unawaited(_ensureBgSpeedCorrect());
    } catch (_) {}
  }

  /// Play boom sound when dynamite chosen in Cautious Miner.
  Future<void> playCautiousMinerBoom() async {
    if (!SettingsService.soundEnabled) return;
    try {
      if (!_cautiousMinerBoomLoaded) {
        await _cautiousMinerBoomPlayer.setAsset(_cautiousMinerBoomAsset);
        _cautiousMinerBoomLoaded = true;
      }
      await _cautiousMinerBoomPlayer.stop();
      await _cautiousMinerBoomPlayer.setVolume(1.0);
      await _cautiousMinerBoomPlayer.seek(Duration.zero);
      await _cautiousMinerBoomPlayer.play();
      unawaited(_ensureBgSpeedCorrect());
    } catch (_) {}
  }

  /// Play drilling sound. Call when drill button (play/next) is pressed.
  /// Asset is loaded once and reused to avoid ExoPlayer init/release churn.
  Future<void> playDrilling() async {
    if (!SettingsService.soundEnabled) return;
    try {
      if (!_drillingLoaded) {
        await _drillingPlayer.setAsset(_drillingAsset);
        _drillingLoaded = true;
      }
      await _drillingPlayer.stop();
      await _drillingPlayer.setVolume(1.0);
      await _drillingPlayer.setSpeed(1.0);
      await _drillingPlayer.seek(Duration.zero);
      await _drillingPlayer.play();
      unawaited(_ensureBgSpeedCorrect());
    } catch (_) {}
  }

  Future<void> playMineDepthTowerRoomDown() async {
    if (!SettingsService.soundEnabled) return;
    try {
      if (!_mineDepthTowerRoomDownLoaded) {
        await _mineDepthTowerRoomDownPlayer.setAsset(
          _mineDepthTowerRoomDownAsset,
        );
        _mineDepthTowerRoomDownLoaded = true;
      }
      await _mineDepthTowerRoomDownPlayer.stop();
      await _mineDepthTowerRoomDownPlayer.setVolume(1.0);
      await _mineDepthTowerRoomDownPlayer.setSpeed(1.0);
      await _mineDepthTowerRoomDownPlayer.seek(Duration.zero);
      await _mineDepthTowerRoomDownPlayer.play();
      unawaited(_ensureBgSpeedCorrect());
    } catch (_) {}
  }

  StreamSubscription<PlayerState>? _loseCompleteSub;

  /// Play win sound. Call when player wins.
  Future<void> playWin() async {
    if (!SettingsService.soundEnabled) return;
    try {
      if (!_winLoaded) {
        await _winPlayer.setAsset(_winAsset);
        _winLoaded = true;
      }
      await _winPlayer.stop();
      await _winPlayer.setVolume(1.0);
      await _winPlayer.seek(Duration.zero);
      await _winPlayer.play();
      unawaited(_ensureBgSpeedCorrect());
    } catch (_) {}
  }

  /// Play lose sound, ducking background music. Call when player loses.
  Future<void> playLose() async {
    if (!SettingsService.soundEnabled) return;
    try {
      _bgVolumeBeforeDuck = _bgPlayer.volume;
      await _bgPlayer.setVolume(_bgDuckedVolume);

      if (!_loseLoaded) {
        await _losePlayer.setAsset(_loseAsset);
        _loseLoaded = true;
      }
      await _losePlayer.stop();
      await _losePlayer.setVolume(1.0);
      await _losePlayer.seek(Duration.zero);
      await _losePlayer.play();

      _loseCompleteSub?.cancel();
      _loseCompleteSub = _losePlayer.playerStateStream.listen((state) async {
        if (state.processingState == ProcessingState.completed) {
          _loseCompleteSub?.cancel();
          _loseCompleteSub = null;
          await _bgPlayer.setVolume(_bgVolumeBeforeDuck);
          unawaited(_ensureBgSpeedCorrect());
        }
      });
    } catch (_) {
      await _bgPlayer.setVolume(_bgVolumeBeforeDuck);
    }
  }

  /// Ensure roulette spin asset is loaded. Call before playRouletteSpin if needed.
  Future<void> ensureRouletteSpinLoaded() async {
    if (_rouletteSpinLoaded) return;
    try {
      await _rouletteSpinPlayer.setAsset(_rouletteSpinAsset);
      _rouletteSpinLoaded = true;
    } catch (_) {}
  }

  /// Play roulette spin (Gold Vein slots) from the start every time, then fade out.
  /// Cancels any previous fade timer so rapid / auto spins always hear a fresh start.
  Future<void> playRouletteSpin(int durationMs) async {
    if (!SettingsService.soundEnabled) return;
    try {
      _rouletteSpinFadeTimer?.cancel();
      _rouletteSpinFadeTimer = null;

      if (!_rouletteSpinLoaded) {
        await ensureRouletteSpinLoaded();
      }

      await _rouletteSpinPlayer.stop();
      await _rouletteSpinPlayer.setVolume(1.0);
      await _rouletteSpinPlayer.seek(Duration.zero);
      await _rouletteSpinPlayer.play();

      final steps = 8;
      final stepMs = (durationMs ~/ steps).clamp(40, 2000);
      var step = 0;
      _rouletteSpinFadeTimer = Timer.periodic(
        Duration(milliseconds: stepMs),
        (t) {
          step++;
          if (step >= steps) {
            t.cancel();
            _rouletteSpinFadeTimer = null;
            unawaited(_rouletteSpinPlayer.stop());
            unawaited(_rouletteSpinPlayer.seek(Duration.zero));
            unawaited(_ensureBgSpeedCorrect());
            return;
          }
          final vol = (1.0 - step / steps).clamp(0.0, 1.0);
          unawaited(_rouletteSpinPlayer.setVolume(vol));
        },
      );
    } catch (_) {}
  }

  /// Dispose players. Call on app exit if needed.
  Future<void> dispose() async {
    _rouletteSpinFadeTimer?.cancel();
    _rouletteSpinFadeTimer = null;
    _bgPositionSub?.cancel();
    _bgStateSub?.cancel();
    _bgSpeedGuardTimer?.cancel();
    _loseCompleteSub?.cancel();
    await _bgPlayer.dispose();
    await _clickPlayer.dispose();
    await _sfxPlayer.dispose();
    await _drillingPlayer.dispose();
    await _mineDepthTowerRoomDownPlayer.dispose();
    await _cardDropPlayer.dispose();
    await _losePlayer.dispose();
    await _winPlayer.dispose();
    await _goldenAvalancheCoinPlayer.dispose();
    for (final p in _gaPegPlayers) {
      await p.dispose();
    }
    await _treasureTrailLadderClaimPlayer.dispose();
    await _cautiousMinerBoomPlayer.dispose();
    await _minersWheelSpinPlayer.dispose();
    await _rouletteSpinPlayer.dispose();
  }
}
