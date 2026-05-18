import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:endvpn/shared/theme/app_theme.dart';

/// Liquid Glass card — blur + border + inner glow
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
    this.blur = 20,
    this.borderRadius = 20,
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
                    Colors.white.withOpacity(0.07),
                    Colors.white.withOpacity(0.02),
                  ]
                : [
                    Colors.white.withOpacity(0.8),
                    Colors.white.withOpacity(0.4),
                  ],
          );

    final border = borderColor ??
        (isDark
            ? Colors.white.withOpacity(0.12)
            : Colors.white.withOpacity(0.6));

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            decoration: BoxDecoration(
              gradient: glassGradient,
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(color: border, width: 1),
              boxShadow: elevation > 0
                  ? [
                      BoxShadow(
                        color: AppColors.neonBlue.withOpacity(0.08),
                        blurRadius: elevation * 4,
                        spreadRadius: 0,
                      ),
                    ]
                  : null,
            ),
            padding: padding ?? const EdgeInsets.all(20),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Neon glow border card — for active/connected state
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
    this.glowIntensity = 1.0,
    this.borderRadius = 24,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: glowColor.withOpacity(0.25 * glowIntensity),
            blurRadius: 30,
            spreadRadius: -4,
          ),
          BoxShadow(
            color: glowColor.withOpacity(0.12 * glowIntensity),
            blurRadius: 60,
            spreadRadius: -10,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  glowColor.withOpacity(0.15),
                  glowColor.withOpacity(0.03),
                  Colors.white.withOpacity(0.03),
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(
                color: glowColor.withOpacity(0.4 * glowIntensity),
                width: 1.5,
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

/// Distortion ripple effect widget для переходов между вкладками
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
