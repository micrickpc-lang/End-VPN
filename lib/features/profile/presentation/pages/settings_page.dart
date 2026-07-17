import 'package:flutter/material.dart';
import 'package:endvpn/main.dart';
import 'package:endvpn/shared/theme/app_theme.dart';
import 'package:endvpn/shared/widgets/glass_card.dart';
import 'package:endvpn/shared/widgets/liquid_glass_button.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  static const _accentColors = [
    AppColors.neonBlue,
    AppColors.crimson,
    AppColors.connected,
    AppColors.warning,
    Color(0xFFB4A7D6),
    Color(0xFFD8B27C),
  ];

  @override
  Widget build(BuildContext context) {
    final app = EndVpnApp.of(context);
    if (app == null) return const SizedBox();

    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded,
              color: AppColors.darkText, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'SETTINGS',
          style: TextStyle(
            fontFamily: 'SpaceMono',
            fontSize: 12,
            letterSpacing: 2,
            color: AppColors.darkText,
          ),
        ),
      ),
      body: LiquidBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
          children: [
            GlassCard(
              blur: 18,
              padding: const EdgeInsets.all(20),
              child: StatefulBuilder(builder: (ctx, setSt) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ACCENT',
                      style: TextStyle(
                        fontFamily: 'SpaceMono',
                        fontSize: 10,
                        color: AppColors.darkTextSub,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: _accentColors.map((c) {
                        final selected = app.accentColor == c;
                        return GestureDetector(
                          onTap: () async {
                            await app.setAccentColor(c);
                            setSt(() {});
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 160),
                            curve: Curves.easeOutCubic,
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: c,
                              border: Border.all(
                                color: selected
                                    ? Colors.white.withValues(alpha: 0.9)
                                    : Colors.white.withValues(alpha: 0.22),
                                width: selected ? 2.5 : 1,
                              ),
                              boxShadow: selected
                                  ? [
                                      BoxShadow(
                                        color: Colors.black
                                            .withValues(alpha: 0.20),
                                        blurRadius: 12,
                                        offset: const Offset(0, 7),
                                      )
                                    ]
                                  : null,
                            ),
                            child: selected
                                ? const Icon(Icons.check_rounded,
                                    color: Colors.white, size: 18)
                                : null,
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                );
              }),
            ),
            const SizedBox(height: 16),
            GlassCard(
              blur: 18,
              padding: const EdgeInsets.all(20),
              child: StatefulBuilder(builder: (ctx, setSt) {
                final liquidSupported = LiquidGlassButton.supported;
                final liquidOn = app.liquidGlassEnabled;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'VPN BUTTON STYLE',
                      style: TextStyle(
                        fontFamily: 'SpaceMono',
                        fontSize: 10,
                        color: AppColors.darkTextSub,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _StyleOption(
                            label: 'Liquid Glass',
                            icon: Icons.blur_circular_rounded,
                            selected: liquidOn,
                            accentColor: app.accentColor,
                            onTap: () async {
                              await app.setLiquidGlass(true);
                              setSt(() {});
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StyleOption(
                            label: 'Classic',
                            icon: Icons.circle_outlined,
                            selected: !liquidOn,
                            accentColor: app.accentColor,
                            onTap: () async {
                              await app.setLiquidGlass(false);
                              setSt(() {});
                            },
                          ),
                        ),
                      ],
                    ),
                    if (!liquidSupported) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Устройство не поддерживает шейдеры — используется Classic',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.darkTextSub.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ],
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

class _StyleOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Color accentColor;
  final VoidCallback onTap;

  const _StyleOption({
    required this.label,
    required this.icon,
    required this.selected,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: selected
              ? accentColor.withValues(alpha: 0.14)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? accentColor.withValues(alpha: 0.55)
                : Colors.white.withValues(alpha: 0.10),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon,
                size: 26,
                color: selected ? accentColor : AppColors.darkTextSub),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Rajdhani',
                fontSize: 14,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                color: selected ? accentColor : AppColors.darkText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
