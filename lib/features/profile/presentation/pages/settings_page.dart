import 'package:flutter/material.dart';
import 'package:endvpn/main.dart';
import 'package:endvpn/shared/theme/app_theme.dart';
import 'package:endvpn/shared/widgets/glass_card.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  static const _accentColors = [
    AppColors.neonBlue,
    AppColors.crimson,
    AppColors.connected,
    AppColors.warning,
    Color(0xFFAA44FF),
    Color(0xFFFF6600),
  ];

  @override
  Widget build(BuildContext context) {
    final app = EndVpnApp.of(context);
    if (app == null) return const SizedBox();

    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: AppColors.darkText, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'НАСТРОЙКИ',
          style: TextStyle(fontFamily: 'SpaceMono', fontSize: 13, letterSpacing: 2, color: AppColors.darkText),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            GlassCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('АКЦЕНТ', style: TextStyle(fontFamily: 'SpaceMono', fontSize: 10, color: AppColors.darkTextSub, letterSpacing: 2)),
                  const SizedBox(height: 16),
                  StatefulBuilder(builder: (ctx, setSt) {
                    return Row(
                      children: _accentColors.map((c) {
                        final selected = app.accentColor == c;
                        return Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: GestureDetector(
                            onTap: () { app.setAccentColor(c); setSt(() {}); },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 36, height: 36,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: c,
                                border: Border.all(color: selected ? Colors.white : Colors.transparent, width: 2.5),
                                boxShadow: selected ? [BoxShadow(color: c.withOpacity(0.6), blurRadius: 12)] : null,
                              ),
                              child: selected ? const Icon(Icons.check_rounded, color: Colors.white, size: 18) : null,
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}