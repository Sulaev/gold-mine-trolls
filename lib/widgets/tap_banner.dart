import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gold_mine_trolls/widgets/pressable_button.dart';

/// Banner with tap hint animation (arms_tap + tap text overlay)
class TapBanner extends StatefulWidget {
  const TapBanner({
    super.key,
    required this.bannerAsset,
    required this.width,
    required this.height,
    this.tapScale = 1.0,
    this.tapOffset = const Offset(100, 36),
    this.onTap,
  });

  final String bannerAsset;
  final double width;
  final double height;
  final double tapScale;
  final Offset tapOffset;
  final VoidCallback? onTap;

  static const _armsTapAsset = 'assets/images/common/arms_tap.png';
  static const _tapAsset = 'assets/images/common/tap.png';
  static const _armsTapWidth = 80.0;
  static const _armsTapHeight = 60.0;
  static const _tapWidth = 50.0;
  static const _tapHeight = 24.0;

  @override
  State<TapBanner> createState() => _TapBannerState();
}

class _TapBannerState extends State<TapBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _armsScaleAnimation;
  late Animation<double> _rippleScaleAnimation;
  late Animation<double> _rippleOpacityAnimation;

  static const _rotationAngle = -0.08; // radians, slight tilt to the left

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _armsScaleAnimation = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    // Ripple appears when finger "taps" (at bottom of motion, value ~0.5)
    _rippleScaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.0), weight: 45),
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 1.2)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 10,
      ),
      TweenSequenceItem(tween: Tween(begin: 1.2, end: 1.2), weight: 5),
      TweenSequenceItem(
        tween: Tween(begin: 1.2, end: 0.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 40,
      ),
    ]).animate(_controller);

    _rippleOpacityAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.0), weight: 45),
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 0.25)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 10,
      ),
      TweenSequenceItem(tween: Tween(begin: 0.25, end: 0.25), weight: 5),
      TweenSequenceItem(
        tween: Tween(begin: 0.25, end: 0.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 40,
      ),
    ]).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PressableButton(
      onTap: () {
        HapticFeedback.lightImpact();
        widget.onTap?.call();
      },
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          Image.asset(
            widget.bannerAsset,
            width: widget.width,
            height: widget.height,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => Container(
              width: widget.width,
              height: widget.height,
              color: Colors.amber.withValues(alpha: 0.2),
              child: const Icon(Icons.card_membership, size: 48),
            ),
          ),
          Positioned(
            bottom: 24,
            left: 0,
            right: 0,
            child: Transform.translate(
              offset: widget.tapOffset,
              child: Transform.rotate(
              angle: _rotationAngle,
              child: Transform.scale(
                scale: widget.tapScale,
                child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ScaleTransition(
                    scale: _armsScaleAnimation,
                    child: SizedBox(
                      width: TapBanner._armsTapWidth,
                      height: TapBanner._armsTapHeight,
                      child: Stack(
                        alignment: Alignment.center,
                        clipBehavior: Clip.none,
                        children: [
                          Image.asset(
                            TapBanner._armsTapAsset,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) =>
                                Icon(
                              Icons.touch_app,
                              size: TapBanner._armsTapHeight,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                          AnimatedBuilder(
                            animation: _controller,
                            builder: (context, child) {
                              return IgnorePointer(
                                child: CustomPaint(
                                  size: const Size(120, 120),
                                  painter: _RipplePainter(
                                    scale: _rippleScaleAnimation.value,
                                    opacity: _rippleOpacityAnimation.value,
                                    centerOffset: const Offset(-8, -12),
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    width: TapBanner._tapWidth,
                    height: TapBanner._tapHeight,
                    child: Image.asset(
                      TapBanner._tapAsset,
                      fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => Center(
                          child: Text(
                            'TAP',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
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
    );
  }
}

class _RipplePainter extends CustomPainter {
  _RipplePainter({
    required this.scale,
    required this.opacity,
    this.centerOffset = Offset.zero,
  });

  final double scale;
  final double opacity;
  final Offset centerOffset;

  @override
  void paint(Canvas canvas, Size size) {
    if (opacity <= 0 || scale <= 0) return;
    final center = Offset(size.width / 2, size.height / 2) + centerOffset;
    final maxRadius = size.width / 2 * scale;
    for (var i = 1; i <= 3; i++) {
      final radius = maxRadius * (i / 3);
      final alpha = opacity * (1 - i / 4) * 0.7;
      final paint = Paint()
        ..color = Colors.white.withValues(alpha: alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RipplePainter oldDelegate) =>
      scale != oldDelegate.scale || opacity != oldDelegate.opacity;
}
