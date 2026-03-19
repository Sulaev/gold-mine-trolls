import 'dart:async';

import 'package:flutter/material.dart';

class WarningPanel extends StatelessWidget {
  const WarningPanel({
    super.key,
    required this.message,
    this.backgroundColor = const Color(0xCC4E2F1C),
    this.textColor = Colors.white,
    this.showCloseButton = true,
    this.onClose,
  });

  final String message;
  final Color backgroundColor;
  final Color textColor;
  /// 18+ onboarding: false — нельзя закрыть по кнопке X
  final bool showCloseButton;
  /// Вызывается при нажатии на крестик (если showCloseButton == true)
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFCE7A2B), width: 1.2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(
              Icons.info_outline_rounded,
              color: Color(0xFFCE7A2B),
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: textColor,
                fontSize: 14,
                fontWeight: FontWeight.w500,
                height: 1.35,
              ),
            ),
          ),
          if (showCloseButton) ...[
            const SizedBox(width: 10),
            GestureDetector(
              onTap: onClose,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  Icons.close_rounded,
                  color: textColor.withValues(alpha: 0.9),
                  size: 22,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Shows a warning as an overlay on top of the content (does not push layout).
/// Slides in from the top, stays for [displayDuration], then slides out.
void showWarningSnackBar(
  BuildContext context,
  String message, {
  Color backgroundColor = const Color(0xCC4E2F1C),
  Duration displayDuration = const Duration(seconds: 2),
  Duration slideDuration = const Duration(milliseconds: 280),
}) {
  final overlay = Overlay.of(context);
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (context) => _WarningOverlay(
      message: message,
      backgroundColor: backgroundColor,
      slideDuration: slideDuration,
      displayDuration: displayDuration,
      onRemove: () {
        entry.remove();
      },
    ),
  );
  overlay.insert(entry);
}

class _WarningOverlay extends StatefulWidget {
  const _WarningOverlay({
    required this.message,
    required this.backgroundColor,
    required this.slideDuration,
    required this.displayDuration,
    required this.onRemove,
  });

  final String message;
  final Color backgroundColor;
  final Duration slideDuration;
  final Duration displayDuration;
  final VoidCallback onRemove;

  @override
  State<_WarningOverlay> createState() => _WarningOverlayState();
}

class _WarningOverlayState extends State<_WarningOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.slideDuration,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));
    _controller.forward();
    _hideTimer = Timer(widget.displayDuration, () {
      if (!mounted) return;
      _hideTimer?.cancel();
      _controller.reverse().then((_) {
        if (mounted) widget.onRemove();
      });
    });
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.paddingOf(context).top;
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Padding(
        padding: EdgeInsets.only(top: topPadding + 8, left: 14, right: 14),
        child: SlideTransition(
          position: _slideAnimation,
          child: Material(
            color: Colors.transparent,
            child: WarningPanel(
              message: widget.message,
              backgroundColor: widget.backgroundColor,
            ),
          ),
        ),
      ),
    );
  }
}
