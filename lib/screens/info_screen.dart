import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Reusable info overlay — info_back.png panel. Tap outside to close.
/// Content is game-specific (passed as child).
class InfoScreen extends StatelessWidget {
  const InfoScreen({
    super.key,
    required this.content,
  });

  final Widget content;

  static const _panelWidth = 360.0;
  static const _panelHeight = 615.0;

  /// Main text style (Gilroy-like): 12px, Bold, #FFFFFF, center.
  static TextStyle mainTextStyle() {
    return GoogleFonts.montserrat(
      fontWeight: FontWeight.w700,
      fontSize: 12,
      height: 1.6,
      letterSpacing: -0.04 * 12,
      color: const Color(0xFFFFFFFF),
    );
  }

  /// Placeholder content for games — use until game-specific content is ready.
  static Widget placeholderContent(String text) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: mainTextStyle(),
        ),
      ),
    );
  }

  /// Multiplier text style (Gotham Ultra): 16px, #F3FF45, uppercase.
  static TextStyle multiplierTextStyle() {
    return const TextStyle(
      fontFamily: 'Gotham',
      fontWeight: FontWeight.w900,
      fontSize: 16,
      height: 1.6,
      letterSpacing: -0.02 * 16,
      color: Color(0xFFF3FF45),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Tap outside to close — no dark overlay
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.of(context).pop();
              },
            ),
          ),
          // Panel — centered, absorbs taps
          Center(
            child: GestureDetector(
              onTap: () {}, // Prevent tap-through to close
              child: SizedBox(
                width: _panelWidth,
                height: _panelHeight,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Image.asset(
                      'assets/images/info/info_back.png',
                      width: _panelWidth,
                      height: _panelHeight,
                      fit: BoxFit.fill,
                      errorBuilder: (context, error, stackTrace) =>
                          Container(
                            width: _panelWidth,
                            height: _panelHeight,
                            decoration: BoxDecoration(
                              color: const Color(0xFF3E2414),
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                    ),
                    Positioned(
                      top: 56,
                      left: 24,
                      right: 24,
                      bottom: 24,
                      child: content,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
