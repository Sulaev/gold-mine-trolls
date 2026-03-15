import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:gold_mine_trolls/services/audio_service.dart';
import 'package:gold_mine_trolls/services/settings_service.dart';
import 'package:gold_mine_trolls/widgets/pressable_button.dart';

/// Settings modal shown over the current screen.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Контент (секции, тумблеры, футер) увеличен на 10%. Панель, title, back_btn — без увеличения.
  static const _scale = 0.968; // 0.88 * 1.1
  static const _panelScale = 0.88; // без увеличения для settigns_back, title, back_btn
  static double get _topPadding => 24.0 * _scale;
  static double get _headerTop => (47.0 + 24.0) * _scale;
  static const _closeBtnSize = 44.0;
  static const _backBtnLeftMargin = 16.0;
  static double get _titleWidth => 150.0 * _panelScale;
  static double get _titleHeight => 42.0 * _panelScale;
  static double get _panelWidth => 390.0 * _panelScale;
  static double get _panelHeight => 390.0 * _panelScale + 80; // +60 к высоте, ещё +20
  static double get _panelHorizontalPadding => 28.0 * _scale;
  static double get _panelContentTop => 60.0 * _scale + 25; // опущено на 25 px
  static double get _labelHeight => 32.0 * _scale;
  static double get _toggleTrackWidth => 80.0 * _scale;
  static double get _toggleTrackHeight => 24.0 * _scale;
  static double get _toggleThumbWidth => 36.0 * _scale;
  static double get _toggleThumbHeight => 24.0 * _scale;
  static double get _sectionGap => 6.0 * _scale;

  static TextStyle _footerLinkStyle() {
    return TextStyle(
      fontFamily: 'Gotham',
      fontWeight: FontWeight.w900,
      fontSize: 16 * _scale,
      height: 1.4,
      letterSpacing: -0.02 * 16 * _scale,
      decoration: TextDecoration.underline,
      decorationColor: Colors.white,
      color: Colors.white,
    );
  }

  static const _vibrationBorderColor = Color(0x40000000);
  static const _vibrationShadowBlur = 2.56;

  static const _vibrationShadows = [
    Shadow(
      color: _vibrationBorderColor,
      offset: Offset(1.28, 1.28),
      blurRadius: _vibrationShadowBlur,
    ),
    Shadow(
      color: _vibrationBorderColor,
      offset: Offset(-1.28, 1.28),
      blurRadius: _vibrationShadowBlur,
    ),
    Shadow(
      color: _vibrationBorderColor,
      offset: Offset(1.28, -1.28),
      blurRadius: _vibrationShadowBlur,
    ),
    Shadow(
      color: _vibrationBorderColor,
      offset: Offset(-1.28, -1.28),
      blurRadius: _vibrationShadowBlur,
    ),
    Shadow(
      color: _vibrationBorderColor,
      offset: Offset(0, 1.28),
      blurRadius: _vibrationShadowBlur,
    ),
    Shadow(
      color: _vibrationBorderColor,
      offset: Offset(0, -1.28),
      blurRadius: _vibrationShadowBlur,
    ),
    Shadow(
      color: _vibrationBorderColor,
      offset: Offset(1.28, 0),
      blurRadius: _vibrationShadowBlur,
    ),
    Shadow(
      color: _vibrationBorderColor,
      offset: Offset(-1.28, 0),
      blurRadius: _vibrationShadowBlur,
    ),
  ];

  Widget _buildVibrationIcon() {
    final size = 30.0 * _scale;
    return SizedBox(
      width: size + 10,
      height: size + 10,
      child: Stack(
        alignment: Alignment.center,
        children: [
          ImageFiltered(
            imageFilter: ui.ImageFilter.blur(
              sigmaX: _vibrationShadowBlur,
              sigmaY: _vibrationShadowBlur,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                for (final offset in const [
                  Offset(1.28, 1.28),
                  Offset(-1.28, 1.28),
                  Offset(1.28, -1.28),
                  Offset(-1.28, -1.28),
                  Offset(0, 1.28),
                  Offset(0, -1.28),
                  Offset(1.28, 0),
                  Offset(-1.28, 0),
                ])
                  Transform.translate(
                    offset: offset,
                    child: Icon(
                      Icons.vibration,
                      color: _vibrationBorderColor,
                      size: size,
                    ),
                  ),
              ],
            ),
          ),
          Icon(
            Icons.vibration,
            color: _vibrationBorderColor,
            size: size + 2.56,
          ),
          Icon(
            Icons.vibration,
            color: Colors.white,
            size: size,
          ),
        ],
      ),
    );
  }

  TextStyle _vibrationLabelStyle({bool stroke = false, bool fill = false}) {
    // Компактная высота: буквы ближе друг к другу
    const lineHeight = 1.0;
    return TextStyle(
      fontFamily: 'Gotham',
      fontWeight: FontWeight.w900,
      fontSize: 24 * _scale,
      height: lineHeight,
      letterSpacing: -0.02 * 24 * _scale,
      color: fill ? Colors.white : null,
      foreground: stroke
          ? (Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.56
            ..color = _vibrationBorderColor)
          : null,
      shadows: fill
          ? _vibrationShadows
          : null,
    );
  }

  bool _soundEnabled = true;
  bool _musicEnabled = true;
  bool _notificationEnabled = true;
  bool _vibrationEnabled = true;

  @override
  void initState() {
    super.initState();
    _soundEnabled = SettingsService.soundEnabled;
    _musicEnabled = SettingsService.musicEnabled;
    _notificationEnabled = SettingsService.notificationEnabled;
    _vibrationEnabled = SettingsService.vibrationEnabled;
  }

  Future<void> _toggleSound() async {
    SettingsService.hapticSelectionClick();
    final next = !_soundEnabled;
    setState(() => _soundEnabled = next);
    await SettingsService.setSoundEnabled(next);
    await AudioService.instance.setSoundEnabled(next);
  }

  Future<void> _toggleMusic() async {
    SettingsService.hapticSelectionClick();
    final next = !_musicEnabled;
    setState(() => _musicEnabled = next);
    await SettingsService.setMusicEnabled(next);
    await AudioService.instance.setMusicEnabled(next);
  }

  Future<void> _toggleNotification() async {
    SettingsService.hapticSelectionClick();
    final next = !_notificationEnabled;
    setState(() => _notificationEnabled = next);
    await SettingsService.setNotificationEnabled(next);
  }

  Future<void> _toggleVibration() async {
    SettingsService.hapticSelectionClick();
    final next = !_vibrationEnabled;
    setState(() => _vibrationEnabled = next);
    await SettingsService.setVibrationEnabled(next);
  }

  Widget _buildToggle(bool value, VoidCallback onTap) {
    return PressableButton(
      onTap: onTap,
      child: SizedBox(
        width: _toggleTrackWidth,
        height: _toggleTrackHeight,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/images/settings/music_back.png',
              fit: BoxFit.fill,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 140),
                curve: Curves.easeOut,
                alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                child: Transform.translate(
                  offset: Offset(value ? 3 : -3, 0),
                  child: SizedBox(
                    width: _toggleThumbWidth,
                    height: _toggleThumbHeight,
                    child: Image.asset(
                      value
                          ? 'assets/images/settings/on.png'
                          : 'assets/images/settings/off.png',
                      fit: BoxFit.fill,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String iconAsset, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: _labelHeight,
          height: _labelHeight,
          child: Image.asset(iconAsset, fit: BoxFit.contain),
        ),
        SizedBox(width: 6 * _scale),
        SizedBox(
          height: 24 * _scale * 1.0,
          child: ClipRect(
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                Text(
                  text,
                  style: _vibrationLabelStyle(stroke: true, fill: false),
                ),
                Text(
                  text,
                  style: _vibrationLabelStyle(stroke: false, fill: true),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSection({
    required String iconAsset,
    required String labelText,
    required bool value,
    required VoidCallback onToggle,
    double? bottomGap,
  }) {
    final gap = bottomGap ?? _sectionGap;
    return Padding(
      padding: EdgeInsets.only(bottom: gap),
      child: Column(
        children: [
          _buildSectionLabel(iconAsset, labelText),
          const SizedBox(height: 0),
          _buildToggle(value, onToggle),
        ],
      ),
    );
  }

  Widget _buildVibrationSection() {
    return Padding(
      padding: EdgeInsets.only(bottom: 0),
      child: Column(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildVibrationIcon(),
              SizedBox(width: 8 * _scale),
              SizedBox(
                height: 24 * _scale * 1.0,
                child: ClipRect(
                  child: Stack(
                    alignment: Alignment.centerLeft,
                    children: [
                      Text(
                        'VIBRATION:',
                        style: _vibrationLabelStyle(stroke: true, fill: false),
                      ),
                      Text(
                        'VIBRATION:',
                        style: _vibrationLabelStyle(stroke: false, fill: true),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 0),
          _buildToggle(_vibrationEnabled, _toggleVibration),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      child: Material(
        color: Colors.transparent,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const Positioned.fill(
              child: ColoredBox(color: Color(0x80000000)),
            ),
            Positioned(
              top: _headerTop,
              left: 0,
              right: 0,
              child: GestureDetector(
                onTap: () {},
                child: Stack(
                  children: [
                    Center(
                      child: SizedBox(
                        width: _titleWidth,
                        height: _titleHeight,
                        child: Image.asset(
                          'assets/images/settings/title.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    Positioned(
                      left: _backBtnLeftMargin,
                      top: (_titleHeight - _closeBtnSize) / 2,
                      child: PressableButton(
                        onTap: () {
                          SettingsService.hapticLightImpact();
                          Navigator.of(context).pop();
                        },
                        child: SizedBox(
                          width: _closeBtnSize,
                          height: _closeBtnSize,
                          child: Image.asset(
                            'assets/images/settings/back_btn.png',
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) =>
                                Container(
                                  decoration: const BoxDecoration(
                                    color: Colors.white24,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Privacy policy', style: _footerLinkStyle()),
                      SizedBox(width: 16 * _scale),
                      Text('Terms of Use', style: _footerLinkStyle()),
                    ],
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: Center(
                child: Transform.translate(
                  offset: const Offset(0, -10),
                  child: GestureDetector(
                    onTap: () {},
                    child: SizedBox(
                      width: _panelWidth,
                      height: _panelHeight,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: Image.asset(
                            'assets/images/settings/settigns_back.png',
                            fit: BoxFit.fill,
                          ),
                        ),
                        Positioned(
                          top: _panelContentTop,
                          left: _panelHorizontalPadding,
                          right: _panelHorizontalPadding,
                          child: Column(
                            children: [
                              _buildSection(
                                iconAsset: 'assets/images/settings/sound.png',
                                labelText: 'SOUND:',
                                value: _soundEnabled,
                                onToggle: _toggleSound,
                              ),
                              _buildSection(
                                iconAsset: 'assets/images/settings/music.png',
                                labelText: 'MUSIC:',
                                value: _musicEnabled,
                                onToggle: _toggleMusic,
                              ),
                              _buildSection(
                                iconAsset:
                                    'assets/images/settings/notification.png',
                                labelText: 'NOTIFICATION:',
                                value: _notificationEnabled,
                                onToggle: _toggleNotification,
                              ),
                              _buildVibrationSection(),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
