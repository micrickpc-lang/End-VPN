import 'package:flutter/material.dart';

class AppColors {
  // Brand colors from logo
  static const neonBlue = Color(0xFF00AAFF);
  static const crimson = Color(0xFFCC1144);
  static const deepDark = Color(0xFF0A0A0F);

  // Dark theme
  static const darkBg = Color(0xFF080810);
  static const darkSurface = Color(0xFF0F0F1A);
  static const darkCard = Color(0xFF141425);
  static const darkBorder = Color(0xFF1E1E35);
  static const darkText = Color(0xFFE8EAFF);
  static const darkTextSub = Color(0xFF7B7D9E);

  // Light theme
  static const lightBg = Color(0xFFF0F4FF);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightCard = Color(0xFFFAFBFF);
  static const lightBorder = Color(0xFFDDE2F5);
  static const lightText = Color(0xFF0A0A1F);
  static const lightTextSub = Color(0xFF6B6E8A);

  // Semantic
  static const connected = Color(0xFF00E5A0);
  static const disconnected = Color(0xFFFF4466);
  static const warning = Color(0xFFFFAA00);

  // Glass
  static Color glassWhite(double opacity) => Colors.white.withOpacity(opacity);
  static Color glassBlue(double opacity) => neonBlue.withOpacity(opacity);
}

class AppTheme {
  static ThemeData dark() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.darkBg,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.neonBlue,
        secondary: AppColors.crimson,
        surface: AppColors.darkSurface,
        background: AppColors.darkBg,
        onPrimary: Colors.white,
        onSurface: AppColors.darkText,
      ),
      fontFamily: 'Rajdhani',
      textTheme: _buildTextTheme(AppColors.darkText, AppColors.darkTextSub),
      extensions: const [AppThemeExtension.dark()],
    );
  }

  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.lightBg,
      colorScheme: const ColorScheme.light(
        primary: AppColors.neonBlue,
        secondary: AppColors.crimson,
        surface: AppColors.lightSurface,
        background: AppColors.lightBg,
        onPrimary: Colors.white,
        onSurface: AppColors.lightText,
      ),
      fontFamily: 'Rajdhani',
      textTheme: _buildTextTheme(AppColors.lightText, AppColors.lightTextSub),
      extensions: const [AppThemeExtension.light()],
    );
  }

  static TextTheme _buildTextTheme(Color primary, Color secondary) {
    return TextTheme(
      displayLarge: TextStyle(
        fontSize: 56,
        fontWeight: FontWeight.w700,
        color: primary,
        letterSpacing: -1,
        fontFamily: 'Rajdhani',
      ),
      displayMedium: TextStyle(
        fontSize: 40,
        fontWeight: FontWeight.w700,
        color: primary,
        letterSpacing: -0.5,
      ),
      headlineLarge: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: primary,
        letterSpacing: 0,
      ),
      headlineMedium: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: primary,
      ),
      titleLarge: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: primary,
        letterSpacing: 0.5,
      ),
      bodyLarge: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: primary,
        fontFamily: 'SpaceMono',
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        color: secondary,
        fontFamily: 'SpaceMono',
      ),
      labelLarge: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: primary,
        letterSpacing: 1.5,
      ),
    );
  }
}

@immutable
class AppThemeExtension extends ThemeExtension<AppThemeExtension> {
  final Color bgColor;
  final Color cardColor;
  final Color borderColor;
  final Color textSub;
  final bool isDark;

  const AppThemeExtension({
    required this.bgColor,
    required this.cardColor,
    required this.borderColor,
    required this.textSub,
    required this.isDark,
  });

  const AppThemeExtension.dark()
      : bgColor = AppColors.darkBg,
        cardColor = AppColors.darkCard,
        borderColor = AppColors.darkBorder,
        textSub = AppColors.darkTextSub,
        isDark = true;

  const AppThemeExtension.light()
      : bgColor = AppColors.lightBg,
        cardColor = AppColors.lightCard,
        borderColor = AppColors.lightBorder,
        textSub = AppColors.lightTextSub,
        isDark = false;

  @override
  AppThemeExtension copyWith({
    Color? bgColor,
    Color? cardColor,
    Color? borderColor,
    Color? textSub,
    bool? isDark,
  }) {
    return AppThemeExtension(
      bgColor: bgColor ?? this.bgColor,
      cardColor: cardColor ?? this.cardColor,
      borderColor: borderColor ?? this.borderColor,
      textSub: textSub ?? this.textSub,
      isDark: isDark ?? this.isDark,
    );
  }

  @override
  AppThemeExtension lerp(AppThemeExtension? other, double t) {
    if (other is! AppThemeExtension) return this;
    return AppThemeExtension(
      bgColor: Color.lerp(bgColor, other.bgColor, t)!,
      cardColor: Color.lerp(cardColor, other.cardColor, t)!,
      borderColor: Color.lerp(borderColor, other.borderColor, t)!,
      textSub: Color.lerp(textSub, other.textSub, t)!,
      isDark: t < 0.5 ? isDark : other.isDark,
    );
  }
}
