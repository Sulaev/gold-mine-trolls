import 'package:flutter/material.dart';
import 'package:gold_mine_trolls/screens/miners_pass_screen.dart';
import 'package:gold_mine_trolls/services/settings_service.dart';
import 'package:gold_mine_trolls/widgets/pressable_button.dart';

/// Miner's Pass button: icon_miners_pass.png + tap hint (arms_tap + tap text), same as on home screen.
/// Use everywhere except shop (shop keeps banner_miner_pass TapBanner).
class MinersPassButton extends StatefulWidget {
  const MinersPassButton({
    super.key,
    required this.width,
    required this.height,
    required this.scale,
    required this.source,
  });

  final double width;
  final double height;
  final double scale;
  final String source;

  @override
  State<MinersPassButton> createState() => _MinersPassButtonState();
}

class _MinersPassButtonState extends State<MinersPassButton>
    with SingleTickerProviderStateMixin {
  /// Tap hint position relative to base size 132x88 (main screen); proportional for other sizes.
  static const _baseW = 132.0;
  static const _baseH = 88.0;
  static const _tapHintLeftRatio = 80.0 / _baseW;
  static const _tapHintTopRatio = 32.0 / _baseH;
  static const _sizeScale = 0.64;

  late final AnimationController _tapHintController;

  @override
  void initState() {
    super.initState();
    _tapHintController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _tapHintController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scale = widget.scale;
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        PressableButton(
          onTap: () {
            SettingsService.hapticLightImpact();
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => MinersPassScreen(source: widget.source),
              ),
            );
          },
          child: SizedBox(
            width: widget.width,
            height: widget.height,
            child: Image.asset(
              'assets/images/main_screen/icon_miners_pass.png',
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => Container(
                color: Colors.amber.withValues(alpha: 0.3),
                child: Icon(Icons.card_membership, size: widget.width * 0.4),
              ),
            ),
          ),
        ),
        Positioned(
          left: widget.width * _tapHintLeftRatio,
          top: widget.height * _tapHintTopRatio,
          child: _buildTapHint(scale),
        ),
      ],
    );
  }

  Widget _buildTapHint(double scale) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _tapHintController,
        builder: (context, child) {
          final t = Curves.easeInOut.transform(_tapHintController.value);
          final hintScale = 0.9 + (0.1 * t);
          return Transform.rotate(
            angle: -0.08,
            child: Transform.scale(
              scale: _sizeScale * hintScale,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 80 * scale,
                    height: 60 * scale,
                    child: Image.asset(
                      'assets/images/common/arms_tap.png',
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => Icon(
                        Icons.touch_app,
                        size: 60 * scale,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                  SizedBox(height: 4 * scale),
                  SizedBox(
                    width: 50 * scale,
                    height: 24 * scale,
                    child: Image.asset(
                      'assets/images/common/tap.png',
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => Text(
                        'TAP',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14 * scale,
                          fontWeight: FontWeight.bold,
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
}
