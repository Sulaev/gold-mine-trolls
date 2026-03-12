import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/launch_screen.dart';
import 'services/analytics_service.dart';
import 'services/audio_service.dart';
import 'services/balance_service.dart';
import 'services/logger_service.dart';
import 'services/settings_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Vertical orientation only
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  LoggerService.init();
  LoggerService.info('Gold Mine Trolls started');

  await AnalyticsService.init();
  await BalanceService.init();
  await SettingsService.init();

  runApp(const GoldMineTrollsApp());
}

bool _bgMusicStarted = false;

void _startBgMusic() {
  if (_bgMusicStarted) return;
  _bgMusicStarted = true;
  AudioService.instance.startBgMusic();
}

class GoldMineTrollsApp extends StatefulWidget {
  const GoldMineTrollsApp({super.key});

  @override
  State<GoldMineTrollsApp> createState() => _GoldMineTrollsAppState();
}

class _GoldMineTrollsAppState extends State<GoldMineTrollsApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _startBgMusic());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      AudioService.instance.onAppResumed();
      AudioService.instance.startBgMusic();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      AudioService.instance.stopBgMusic();
      if (state == AppLifecycleState.paused ||
          state == AppLifecycleState.detached) {
        AnalyticsService.reportAppClose();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gold Mine Trolls',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.amber),
        useMaterial3: true,
      ),
      home: const LaunchScreen(),
    );
  }
}
