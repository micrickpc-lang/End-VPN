import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// iOS-26-style liquid glass lens: refracts the backdrop through a fragment
/// shader (edge refraction, chromatic aberration, specular sweep, mirror rim).
class LiquidGlassButton extends StatefulWidget {
  final double size;
  final Color stateColor;
  final double stateMix;
  final double pulse;
  final VoidCallback? onTap;
  final Widget child;
  final Widget? fallback;

  const LiquidGlassButton({
    super.key,
    this.size = 180,
    required this.stateColor,
    required this.stateMix,
    this.pulse = 0,
    this.onTap,
    required this.child,
    this.fallback,
  });

  static ui.FragmentProgram? _program;
  static bool _loadFailed = false;
  static bool? _filterSupported;

  static bool get supported {
    if (_loadFailed) return false;
    if (_filterSupported == null) {
      try {
        _filterSupported = ui.ImageFilter.isShaderFilterSupported;
      } catch (_) {
        _filterSupported = false;
      }
    }
    return _filterSupported!;
  }

  static Future<bool> ensureLoaded() async {
    if (!supported) return false;
    if (_program != null) return true;
    try {
      _program =
          await ui.FragmentProgram.fromAsset('shaders/liquid_glass.frag');
      return true;
    } catch (_) {
      _loadFailed = true;
      return false;
    }
  }

  @override
  State<LiquidGlassButton> createState() => _LiquidGlassButtonState();
}

class _LiquidGlassButtonState extends State<LiquidGlassButton>
    with SingleTickerProviderStateMixin {
  ui.FragmentShader? _shader;
  late final Ticker _ticker;
  double _time = 0;
  double _press = 0;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    LiquidGlassButton.ensureLoaded().then((ok) {
      if (!ok || !mounted) return;
      setState(() => _shader = LiquidGlassButton._program!.fragmentShader());
      _ticker.start();
    });
  }

  void _onTick(Duration elapsed) {
    if (!mounted) return;
    setState(() {
      _time = elapsed.inMicroseconds / 1e6;
      final target = _pressed ? 1.0 : 0.0;
      _press += (target - _press) * 0.18;
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    _shader?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shader = _shader;
    if (shader == null) {
      return widget.fallback ?? SizedBox.square(dimension: widget.size);
    }

    final scale = 1.0 + widget.pulse * 0.03 - _press * 0.04;
    final tint = widget.stateColor;

    shader
      ..setFloat(2, _time)
      ..setFloat(3, _press)
      ..setFloat(4, widget.stateMix)
      ..setFloat(5, tint.r)
      ..setFloat(6, tint.g)
      ..setFloat(7, tint.b)
      ..setFloat(8, 1.0);

    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => _pressed = true,
      onTapUp: (_) => _pressed = false,
      onTapCancel: () => _pressed = false,
      child: Transform.scale(
        scale: scale,
        child: SizedBox.square(
          dimension: widget.size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: tint.withValues(
                          alpha: 0.18 + 0.30 * widget.stateMix),
                      blurRadius: 40 + 14 * widget.stateMix,
                      offset: const Offset(0, 16),
                    ),
                  ],
                ),
              ),
              ClipOval(
                child: BackdropFilter(
                  filter: ui.ImageFilter.shader(shader),
                  child: SizedBox.square(
                    dimension: widget.size,
                    child: Center(child: widget.child),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
