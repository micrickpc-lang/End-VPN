import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:endvpn/shared/theme/app_theme.dart';

class LiquidBackground extends StatelessWidget {
  final Widget child;

  const LiquidBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return RepaintBoundary(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? const [
                    Color(0xFF151515),
                    Color(0xFF101112),
                    Color(0xFF191714),
                  ]
                : const [
                    Color(0xFFF7F8F6),
                    Color(0xFFEFF3F1),
                    Color(0xFFF6F0E8),
                  ],
          ),
        ),
        child: CustomPaint(
          painter: _LiquidBackgroundPainter(isDark: isDark),
          child: child,
        ),
      ),
    );
  }
}

class _LiquidBackgroundPainter extends CustomPainter {
  final bool isDark;

  const _LiquidBackgroundPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final veil = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: isDark
            ? const [
                Color(0x18FFFFFF),
                Color(0x05000000),
                Color(0x24000000),
              ]
            : const [
                Color(0x55FFFFFF),
                Color(0x18DDEBE6),
                Color(0x22DCC9B4),
              ],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, veil);

    final wavePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..color = (isDark ? Colors.white : AppColors.lightText)
          .withValues(alpha: isDark ? 0.045 : 0.055);

    for (var i = 0; i < 7; i++) {
      final y = size.height * (0.12 + i * 0.13);
      final path = Path()..moveTo(-size.width * 0.1, y);
      path.cubicTo(
        size.width * 0.25,
        y - 34,
        size.width * 0.55,
        y + 40,
        size.width * 1.1,
        y - 8,
      );
      canvas.drawPath(path, wavePaint);
    }

    final sheenPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 22
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: isDark ? 0.018 : 0.34);
    canvas.drawLine(
      Offset(size.width * 0.08, size.height * 0.06),
      Offset(size.width * 0.92, size.height * 0.34),
      sheenPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _LiquidBackgroundPainter oldDelegate) =>
      oldDelegate.isDark != isDark;
}

class GlassCard extends StatelessWidget {
  final Widget child;
  final double blur;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final Color? borderColor;
  final List<Color>? gradientColors;
  final VoidCallback? onTap;
  final double elevation;

  const GlassCard({
    super.key,
    required this.child,
    this.blur = 24,
    this.borderRadius = 28,
    this.padding,
    this.borderColor,
    this.gradientColors,
    this.onTap,
    this.elevation = 0,
  });

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    final isDark = ext.isDark;

    final glassGradient = gradientColors != null
        ? LinearGradient(colors: gradientColors!)
        : LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    Colors.white.withValues(alpha: 0.16),
                    Colors.white.withValues(alpha: 0.075),
                    Colors.white.withValues(alpha: 0.045),
                  ]
                : [
                    Colors.white.withValues(alpha: 0.86),
                    Colors.white.withValues(alpha: 0.56),
                    Colors.white.withValues(alpha: 0.38),
                  ],
          );

    final border = borderColor ??
        (isDark
            ? Colors.white.withValues(alpha: 0.18)
            : Colors.white.withValues(alpha: 0.64));

    final decorated = Container(
      decoration: BoxDecoration(
        gradient: glassGradient,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: border, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 28 + elevation * 2,
            offset: const Offset(0, 14),
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.035),
            blurRadius: 1,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      padding: padding ?? const EdgeInsets.all(20),
      child: child,
    );

    final content = RepaintBoundary(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: blur <= 0
            ? decorated
            : BackdropFilter(
                filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
                child: decorated,
              ),
      ),
    );

    if (onTap == null) return content;
    return GestureDetector(onTap: onTap, child: content);
  }
}

class NeonGlassCard extends StatelessWidget {
  final Widget child;
  final Color glowColor;
  final double glowIntensity;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;

  const NeonGlassCard({
    super.key,
    required this.child,
    this.glowColor = AppColors.neonBlue,
    this.glowIntensity = 0.55,
    this.borderRadius = 30,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 28,
            offset: const Offset(0, 16),
          ),
          BoxShadow(
            color: glowColor.withValues(alpha: 0.10 * glowIntensity),
            blurRadius: 36,
            spreadRadius: -8,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.18),
                  glowColor.withValues(alpha: 0.10),
                  Colors.white.withValues(alpha: 0.055),
                ],
                stops: const [0.0, 0.48, 1.0],
              ),
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.20),
                width: 1,
              ),
            ),
            padding: padding ?? const EdgeInsets.all(24),
            child: child,
          ),
        ),
      ),
    );
  }
}

class WarpTransitionBuilder {
  static Widget buildPageTransition({
    required Animation<double> animation,
    required Widget child,
  }) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final t = animation.value;
        return ImageFiltered(
          imageFilter: ImageFilter.blur(
            sigmaX: (1 - t) * 12,
            sigmaY: (1 - t) * 6,
          ),
          child: Transform.scale(
            scale: 0.92 + (t * 0.08),
            child: Opacity(
              opacity: t,
              child: child,
            ),
          ),
        );
      },
      child: child,
    );
  }
}
