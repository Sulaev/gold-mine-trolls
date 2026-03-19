import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gold_mine_trolls/services/daily_bonus_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gold_mine_trolls/assets/common_assets.dart';
import 'package:gold_mine_trolls/legal_links.dart';
import 'package:gold_mine_trolls/services/audio_service.dart';
import 'package:gold_mine_trolls/widgets/pressable_button.dart';
import 'package:gold_mine_trolls/widgets/warning_panel.dart';
import 'home_screen.dart';
import 'welcome_bonus_screen.dart';

/// Asset paths for onboarding (place PNGs in assets/images/onboarding/)
class OnboardingAssets {
  static const logo = 'assets/images/onboarding/logo.png';
  static const buttonLetsPlay = 'assets/images/onboarding/btn_lets_play_active.png';
  static const buttonLetsPlayDisabled =
      'assets/images/onboarding/btn_lets_play_disabled.png';
  static const loadingTrack = 'assets/images/onboarding/loading_track.png';
  static const checkboxCheck = 'assets/images/onboarding/checkbox_check.png';
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  double _loadingProgress = 0;
  bool _termsAccepted = false;
  bool _loadingComplete = false;
  bool _warningDismissed = false;

  bool get _canPlay =>
      _loadingComplete && _termsAccepted;

  bool get _showAgeWarning =>
      _loadingComplete && !_termsAccepted && !_warningDismissed;

  @override
  void initState() {
    super.initState();
    _loadTermsAccepted();
    WidgetsBinding.instance.addPostFrameCallback((_) => _performLoading());
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadTermsAccepted() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _termsAccepted = prefs.getBool('terms_accepted') ?? true);
  }

  Future<void> _performLoading() async {
    const minDuration = Duration(milliseconds: 2500);
    try {
      await Future.wait([
        _precacheAll(),
        Future<void>.delayed(minDuration),
      ]);
    } catch (_) {
      // Never block app start because one asset failed to warm up.
    }
    if (!mounted) return;
    setState(() {
      _loadingProgress = 1.0;
      _loadingComplete = true;
    });
  }

  Future<void> _precacheAll() async {
    if (!mounted) return;

    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final allAssets = manifest.listAssets();

    final rasterAssets = allAssets
        .where(
          (path) =>
              path.startsWith('assets/images/') &&
              (path.endsWith('.png') ||
                  path.endsWith('.jpg') ||
                  path.endsWith('.jpeg') ||
                  path.endsWith('.webp')),
        )
        .toList()
      ..sort();
    final svgAssets = allAssets
        .where(
          (path) => path.startsWith('assets/images/') && path.endsWith('.svg'),
        )
        .toList()
      ..sort();
    final soundAssets = allAssets
        .where((path) => path.startsWith('assets/sounds/'))
        .toList()
      ..sort();

    final totalTasks =
        rasterAssets.length + svgAssets.length + soundAssets.length + 2;
    var completedTasks = 0;

    void updateProgress() {
      if (!mounted || totalTasks == 0) return;
      setState(() {
        _loadingProgress = completedTasks / totalTasks;
      });
    }

    final imageCache = PaintingBinding.instance.imageCache;
    imageCache.maximumSize = math.max(imageCache.maximumSize, rasterAssets.length + 100);
    imageCache.maximumSizeBytes =
        math.max(imageCache.maximumSizeBytes, 512 << 20);

    for (final path in rasterAssets) {
      if (!mounted) return;
      try {
        await precacheImage(AssetImage(path), context);
      } catch (_) {}
      completedTasks++;
      updateProgress();
    }

    for (final path in svgAssets) {
      if (!mounted) return;
      try {
        await rootBundle.loadString(path);
      } catch (_) {}
      completedTasks++;
      updateProgress();
    }

    for (final path in soundAssets) {
      if (!mounted) return;
      try {
        await rootBundle.load(path);
      } catch (_) {}
      completedTasks++;
      updateProgress();
    }

    await AudioService.instance.preloadAssets();
    completedTasks++;
    updateProgress();

    await GoogleFonts.pendingFonts(<TextStyle>[
      GoogleFonts.montserrat(fontWeight: FontWeight.w400),
      GoogleFonts.montserrat(fontWeight: FontWeight.w700),
      GoogleFonts.montserrat(fontWeight: FontWeight.w900),
      GoogleFonts.gothicA1(fontWeight: FontWeight.w400),
      GoogleFonts.gothicA1(fontWeight: FontWeight.w700),
      GoogleFonts.gothicA1(fontWeight: FontWeight.w900),
    ]);
    completedTasks++;
    updateProgress();
  }

  Future<void> _onLetsPlay() async {
    if (!_canPlay) return;

    HapticFeedback.lightImpact();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('terms_accepted', true);
    await prefs.setBool('onboarding_completed', true);
    const _testModeAlwaysShowWelcomeBonus = false;
    final isBonusAvailable = _testModeAlwaysShowWelcomeBonus ||
        await DailyBonusService.isBonusAvailableToday();

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => isBonusAvailable
            ? const WelcomeBonusScreen()
            : const HomeScreen(),
      ),
    );
  }

  Future<void> _onTermsTap() async {
    HapticFeedback.selectionClick();
    final newValue = !_termsAccepted;
    setState(() {
      _termsAccepted = newValue;
      if (!newValue) _warningDismissed = false;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('terms_accepted', newValue);
  }

  void _onAgeWarningDismiss() {
    HapticFeedback.lightImpact();
    setState(() => _warningDismissed = true);
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.paddingOf(context).top;
    return Scaffold(
      backgroundColor: const Color(0xFF1A1510),
      body: Stack(
        fit: StackFit.expand,
        children: [
          _buildBackground(),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              height: 145,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0x00702F18),
                    const Color(0xFF702F18),
                  ],
                ),
              ),
            ),
          ),
          if (_showAgeWarning)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Padding(
                padding: EdgeInsets.only(
                  top: topPadding + 8,
                  left: 24,
                  right: 24,
                ),
                child: Material(
                  color: Colors.transparent,
                  child: Dismissible(
                    key: const ValueKey('age_warning'),
                    direction: DismissDirection.up,
                    onDismissed: (_) => _onAgeWarningDismiss(),
                    child: WarningPanel(
                      message:
                          'Please confirm that you are at least 18 years old and agree to the Terms of Use and Privacy Policy.',
                      backgroundColor: const Color(0xCC4E2F1C),
                      showCloseButton: true,
                      onClose: _onAgeWarningDismiss,
                    ),
                  ),
                ),
              ),
            ),
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 80),
                _buildLogo(),
                const Spacer(),
                _buildLetsPlayButton(),
                const SizedBox(height: 20),
                _buildLoadingBar(),
                const SizedBox(height: 39),
                _buildTermsSection(),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackground() {
    return Positioned.fill(
      child: Image.asset(
        CommonAssets.background,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF1A1510),
                Color(0xFF2D2418),
                Color(0xFF1A1510),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return SizedBox(
      width: 336,
      height: 241,
      child: Image.asset(
        OnboardingAssets.logo,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => Text(
          'GOLD MINE\nTROLLS',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.amber.shade700,
            fontSize: 48,
            fontWeight: FontWeight.bold,
            height: 1.1,
          ),
        ),
      ),
    );
  }

  static const double _buttonWidth = 212;
  static const double _buttonHeight = 82;

  Widget _buildLetsPlayButton() {
    final isActive = _canPlay;

    return PressableButton(
      onTap: isActive ? _onLetsPlay : null,
      child: AnimatedOpacity(
        opacity: isActive ? 1 : 0.7,
        duration: const Duration(milliseconds: 200),
        child: SizedBox(
          width: _buttonWidth,
          height: _buttonHeight,
          child: Image.asset(
            isActive
                ? OnboardingAssets.buttonLetsPlay
                : OnboardingAssets.buttonLetsPlayDisabled,
            fit: BoxFit.fill,
            errorBuilder: (context, error, stackTrace) => Container(
              width: _buttonWidth,
              height: _buttonHeight,
              alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isActive
                  ? const Color(0xFFFFB347)
                  : const Color(0xFF5A5A5A),
              borderRadius: BorderRadius.circular(_buttonHeight / 2),
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: Colors.amber.withValues(alpha: 0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: Text(
                "Let's play",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
        ),
      ),
    );
  }

  Widget _buildLoadingBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final barWidth = constraints.maxWidth;
          final progress = _loadingProgress.clamp(0.0, 1.0);
          final fillWidth = barWidth * progress;
          return SizedBox(
            height: 48,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.centerLeft,
              children: [
                Positioned.fill(
                  child: Image.asset(
                    OnboardingAssets.loadingTrack,
                    fit: BoxFit.fill,
                    errorBuilder: (context, error, stackTrace) => Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF4A3528),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFFFFB347).withValues(alpha: 0.5),
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 4,
                  top: 4,
                  bottom: 4,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 100),
                    width: (fillWidth - 8).clamp(0.0, barWidth - 8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFFFFD54F),
                          Color(0xFFFFB347),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.amber.withValues(alpha: 0.5),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTermsSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          PressableButton(
            onTap: _onTermsTap,
            child: Transform.translate(
              offset: const Offset(0, 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildCheckbox(),
                  const SizedBox(width: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: () => LegalLinks.openTermsOfUse(),
                        child: Text(
                          'TERMS OF USE',
                          style: GoogleFonts.gothicA1(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            height: 1.6,
                            letterSpacing: 0,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                      Text(
                        ' | ',
                        style: GoogleFonts.gothicA1(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          height: 1.6,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => LegalLinks.openPrivacyPolicy(),
                        child: Text(
                          'PRIVACY POLICY',
                          style: GoogleFonts.gothicA1(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            height: 1.6,
                            letterSpacing: 0,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'By using this app, you confirm that you are at least 18 years old '
            'and agree to our Terms of Use and Privacy Policy.',
            textAlign: TextAlign.center,
            style: GoogleFonts.gothicA1(
              color: const Color(0xFFFFFFFF),
              fontSize: 12,
              fontWeight: FontWeight.w400,
              height: 1.6,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildCheckbox() {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(
          color: const Color(0xFFFFEA4C),
          width: 0.75,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0x40FFEA4C),
            blurRadius: 3,
            spreadRadius: 1.5,
            blurStyle: BlurStyle.outer,
          ),
        ],
      ),
      child: _termsAccepted
          ? Padding(
              padding: const EdgeInsets.all(4),
              child: Image.asset(
                OnboardingAssets.checkboxCheck,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) =>
                    const Icon(Icons.check, size: 14, color: Color(0xFF1A1510)),
              ),
            )
          : null,
    );
  }
}
