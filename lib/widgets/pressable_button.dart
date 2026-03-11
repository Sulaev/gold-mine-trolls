import 'package:flutter/material.dart';
import 'package:gold_mine_trolls/services/audio_service.dart';

/// Reusable press animation wrapper that creates a subtle "pressed in" effect.
class PressableButton extends StatefulWidget {
  const PressableButton({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPressStart,
    this.onLongPressEnd,
    this.onLongPressCancel,
    this.behavior = HitTestBehavior.opaque,
    this.pressedScale = 0.985,
    this.pressedOffset = const Offset(0, 0.6),
    this.duration = const Duration(milliseconds: 85),
  });

  final Widget child;
  final VoidCallback? onTap;
  final GestureLongPressStartCallback? onLongPressStart;
  final GestureLongPressEndCallback? onLongPressEnd;
  final VoidCallback? onLongPressCancel;
  final HitTestBehavior behavior;
  final double pressedScale;
  final Offset pressedOffset;
  final Duration duration;

  @override
  State<PressableButton> createState() => _PressableButtonState();
}

class _PressableButtonState extends State<PressableButton> {
  bool _pressed = false;
  DateTime? _pressedAt;
  static const Duration _minVisiblePress = Duration(milliseconds: 55);

  void _setPressed(bool value) {
    if (_pressed == value) return;
    if (value) _pressedAt = DateTime.now();
    setState(() => _pressed = value);
  }

  Future<void> _releasePressed() async {
    if (!_pressed) return;
    final startedAt = _pressedAt;
    if (startedAt != null) {
      final elapsed = DateTime.now().difference(startedAt);
      final left = _minVisiblePress - elapsed;
      if (left > Duration.zero) {
        await Future.delayed(left);
      }
    }
    if (!mounted) return;
    _setPressed(false);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: widget.behavior,
      onTap: () {
        AudioService.instance.playButtonClick();
        widget.onTap?.call();
      },
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _releasePressed(),
      onTapCancel: _releasePressed,
      onLongPressStart: (details) {
        _setPressed(true);
        widget.onLongPressStart?.call(details);
      },
      onLongPressEnd: (details) {
        _releasePressed();
        widget.onLongPressEnd?.call(details);
      },
      onLongPressCancel: () {
        _releasePressed();
        widget.onLongPressCancel?.call();
      },
      child: AnimatedSlide(
        duration: widget.duration,
        curve: Curves.easeOut,
        offset: _pressed
            ? Offset(
                widget.pressedOffset.dx / 20,
                widget.pressedOffset.dy / 20,
              )
            : Offset.zero,
        child: AnimatedScale(
          duration: widget.duration,
          curve: Curves.easeOut,
          scale: _pressed ? widget.pressedScale : 1.0,
          child: widget.child,
        ),
      ),
    );
  }
}
