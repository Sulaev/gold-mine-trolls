import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  static const _topPadding = 24.0;
  static const _headerTop = 47.0 + _topPadding;
  static const _closeBtnSize = 44.0;
  static const _backBtnLeftMargin = 16.0;
  static const _titleWidth = 150.0;
  static const _titleHeight = 42.0;
  static const _panelSize = 390.0;
  static const _panelHorizontalPadding = 28.0;
  static const _panelContentTop = 74.0;
  static const _labelHeight = 38.0;
  static const _toggleTrackWidth = 80.0;
  static const _toggleTrackHeight = 24.0;
  static const _toggleThumbWidth = 36.0;
  static const _toggleThumbHeight = 24.0;
  static const _sectionGap = 12.0;

  bool _soundEnabled = true;
  bool _musicEnabled = true;
  bool _notificationEnabled = true;

  @override
  void initState() {
    super.initState();
    _soundEnabled = SettingsService.soundEnabled;
    _musicEnabled = SettingsService.musicEnabled;
    _notificationEnabled = SettingsService.notificationEnabled;
  }

  Future<void> _toggleSound() async {
    HapticFeedback.selectionClick();
    final next = !_soundEnabled;
    setState(() => _soundEnabled = next);
    await SettingsService.setSoundEnabled(next);
    await AudioService.instance.setSoundEnabled(next);
  }

  Future<void> _toggleMusic() async {
    HapticFeedback.selectionClick();
    final next = !_musicEnabled;
    setState(() => _musicEnabled = next);
    await SettingsService.setMusicEnabled(next);
    await AudioService.instance.setMusicEnabled(next);
  }

  Future<void> _toggleNotification() async {
    HapticFeedback.selectionClick();
    final next = !_notificationEnabled;
    setState(() => _notificationEnabled = next);
    await SettingsService.setNotificationEnabled(next);
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
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required String labelAsset,
    required double labelWidth,
    required bool value,
    required VoidCallback onToggle,
    double bottomGap = _sectionGap,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: bottomGap),
      child: Column(
        children: [
          SizedBox(
            width: labelWidth,
            height: _labelHeight,
            child: Image.asset(labelAsset, fit: BoxFit.contain),
          ),
          const SizedBox(height: 0),
          _buildToggle(value, onToggle),
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
                          HapticFeedback.lightImpact();
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
            Positioned.fill(
              child: Center(
                child: GestureDetector(
                  onTap: () {},
                  child: SizedBox(
                    width: _panelSize,
                    height: _panelSize,
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
                                labelAsset: 'assets/images/settings/sound.png',
                                labelWidth: 131,
                                value: _soundEnabled,
                                onToggle: _toggleSound,
                              ),
                              _buildSection(
                                labelAsset: 'assets/images/settings/music.png',
                                labelWidth: 120,
                                value: _musicEnabled,
                                onToggle: _toggleMusic,
                              ),
                              _buildSection(
                                labelAsset:
                                    'assets/images/settings/notification.png',
                                labelWidth: 213,
                                value: _notificationEnabled,
                                bottomGap: 0,
                                onToggle: _toggleNotification,
                              ),
                            ],
                          ),
                        ),
                      ],
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
