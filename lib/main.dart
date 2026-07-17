import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:endvpn/app_shell.dart';
import 'package:endvpn/features/auth/presentation/pages/auth_page.dart';
import 'package:endvpn/shared/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Colors.transparent,
  ));

  final prefs = await SharedPreferences.getInstance();
  final accentValue =
      prefs.getInt('accent_color') ?? AppColors.neonBlue.toARGB32();
  final tosAccepted = prefs.getBool('tos_accepted') ?? false;
  final liquidGlass = prefs.getBool('liquid_glass') ?? true;

  runApp(EndVpnApp(
    accentColor: Color(accentValue),
    tosAccepted: tosAccepted,
    liquidGlass: liquidGlass,
  ));
}

class EndVpnApp extends StatefulWidget {
  final Color accentColor;
  final bool tosAccepted;
  final bool liquidGlass;
  const EndVpnApp({
    super.key,
    required this.accentColor,
    required this.tosAccepted,
    this.liquidGlass = true,
  });

  static EndVpnAppState? of(BuildContext context) =>
      context.findAncestorStateOfType<EndVpnAppState>();

  @override
  State<EndVpnApp> createState() => EndVpnAppState();
}

class EndVpnAppState extends State<EndVpnApp> {
  late Color _accentColor;
  late bool _tosAccepted;
  late bool _liquidGlass;

  @override
  void initState() {
    super.initState();
    _accentColor = widget.accentColor;
    _tosAccepted = widget.tosAccepted;
    _liquidGlass = widget.liquidGlass;
  }

  Future<void> setAccentColor(Color color) async {
    setState(() => _accentColor = color);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('accent_color', color.toARGB32());
  }

  Future<void> setLiquidGlass(bool enabled) async {
    setState(() => _liquidGlass = enabled);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('liquid_glass', enabled);
  }

  void onTosAccepted() {
    setState(() => _tosAccepted = true);
  }

  Color get accentColor => _accentColor;
  bool get liquidGlassEnabled => _liquidGlass;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EndVPN',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.dark,
      home: _tosAccepted
          ? AppShell(accentColor: _accentColor, liquidGlass: _liquidGlass)
          : AuthPage(onAccepted: onTosAccepted),
    );
  }
}
