import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:endvpn/features/home/presentation/pages/home_page.dart';
import 'package:endvpn/features/clicker/presentation/pages/clicker_page.dart';
import 'package:endvpn/features/profile/presentation/pages/profile_page.dart';
import 'package:endvpn/core/models/user_model.dart';
import 'package:endvpn/core/services/remnawave_service.dart';
import 'package:endvpn/shared/theme/app_theme.dart';

class AppShell extends StatefulWidget {
  final UserModel? user;
  final Color accentColor;
  const AppShell({super.key, this.user, required this.accentColor});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with TickerProviderStateMixin {
  int _currentIndex = 0;
  UserModel? _user;
  bool _userLoading = true;
  bool _vpnConnected = false;

  late Color _accentColor;
  bool _userUpdatedLocally = false;

  late final AnimationController _tabController;

  @override
  void initState() {
    super.initState();
    _accentColor = widget.accentColor;
    _tabController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
      value: 1.0,
    );
    if (widget.user != null) {
      _user = widget.user;
      _userLoading = false;
    } else {
      _loadUser();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncAccentColor());
  }

  Future<void> _syncAccentColor() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getInt('accent_color');
    if (value != null && mounted) {
      setState(() => _accentColor = Color(value));
    }
  }

  @override
  void didUpdateWidget(AppShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.accentColor != oldWidget.accentColor) {
      setState(() => _accentColor = widget.accentColor);
    }
  }

  Future<void> _loadUser() async {
    try {
      RemnawaveService().init();
      final tgIdStr = await RemnawaveService().getSavedTgId();
      if (tgIdStr == null) {
        final anonUser = await RemnawaveService().getOrCreateAnonUser();
        if (mounted) setState(() { _user = anonUser; _userLoading = false; });
        return;
      }
      final user = await RemnawaveService().getOrCreateUserByTgId(int.parse(tgIdStr));
      if (mounted) setState(() { _user = user; _userLoading = false; });
    } catch (e) {
      debugPrint('AppShell _loadUser error: $e');
      try {
        final anonUser = await RemnawaveService().getOrCreateAnonUser();
        if (mounted) setState(() { _user = anonUser; _userLoading = false; });
      } catch (_) {
        if (mounted) setState(() { _user = UserModel.mock(); _userLoading = false; });
      }
    }
  }

  Future<void> _refreshUser() async {
    if (_userUpdatedLocally) return;
    try {
      final tgIdStr = await RemnawaveService().getSavedTgId();
      UserModel user;
      if (tgIdStr != null) {
        user = await RemnawaveService().getOrCreateUserByTgId(int.parse(tgIdStr));
      } else {
        user = await RemnawaveService().getOrCreateAnonUser();
      }
      if (mounted) setState(() => _user = user);
    } catch (_) {}
  }

  Future<void> _switchTab(int index) async {
    if (index == _currentIndex) return;
    await _tabController.reverse();
    setState(() => _currentIndex = index);
    _tabController.forward();
    if (index == 2) _refreshUser();
  }

  void _onUserUpdated(UserModel u) {
    setState(() {
      _user = u;
      _userUpdatedLocally = true;
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_userLoading) {
      return const Scaffold(
        backgroundColor: AppColors.darkBg,
        body: Center(child: CircularProgressIndicator(color: AppColors.neonBlue)),
      );
    }

    final user = _user!;

    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: AnimatedBuilder(
        animation: _tabController,
        builder: (context, child) => Opacity(
          opacity: _tabController.value.clamp(0.0, 1.0),
          child: child,
        ),
        child: IndexedStack(
          index: _currentIndex,
          children: [
            const HomePage(),
            const ClickerPage(),
            ProfilePage(
              key: const ValueKey('profile_stable'),
              user: user,
              accentColor: _accentColor,
              onUserUpdated: _onUserUpdated,
            ),
          ],
        ),
      ),
      bottomNavigationBar: _WarpNavBar(
        currentIndex: _currentIndex,
        vpnConnected: _vpnConnected,
        accentColor: _accentColor,
        onTap: _switchTab,
      ),
    );
  }
}

class _WarpNavBar extends StatelessWidget {
  final int currentIndex;
  final bool vpnConnected;
  final Color accentColor;
  final ValueChanged<int> onTap;

  const _WarpNavBar({
    required this.currentIndex,
    required this.vpnConnected,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, bottomPad + 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            height: 64,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(0.09),
                  Colors.white.withOpacity(0.04),
                ],
              ),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: Colors.white.withOpacity(0.12), width: 1),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavItem(
                  icon: Icons.shield_rounded,
                  label: 'VPN',
                  isSelected: currentIndex == 0,
                  badge: vpnConnected,
                  accentColor: accentColor,
                  onTap: () => onTap(0),
                ),
                _NavItem(
                  icon: Icons.touch_app_rounded,
                  label: 'Клик',
                  isSelected: currentIndex == 1,
                  accentColor: accentColor,
                  onTap: () => onTap(1),
                ),
                _NavItem(
                  icon: Icons.person_rounded,
                  label: 'Профиль',
                  isSelected: currentIndex == 2,
                  accentColor: accentColor,
                  onTap: () => onTap(2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavLogoItem extends StatelessWidget {
  final bool isSelected;
  final bool badge;
  final Color accentColor;
  final VoidCallback onTap;

  const _NavLogoItem({
    required this.isSelected,
    required this.accentColor,
    required this.onTap,
    this.badge = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 80,
        height: 64,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: isSelected ? accentColor.withOpacity(0.2) : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: isSelected
                        ? [BoxShadow(color: accentColor.withOpacity(0.3), blurRadius: 10)]
                        : null,
                  ),
                  child: Image.asset(
                    'assets/images/logo.png',
                    width: 24,
                    height: 24,
                    fit: BoxFit.contain,
                  ),
                ),
                if (badge)
                  Positioned(
                    top: -2, right: -2,
                    child: Container(
                      width: 8, height: 8,
                      decoration: BoxDecoration(
                        color: AppColors.connected,
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: AppColors.connected.withOpacity(0.6), blurRadius: 4)],
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              'VPN',
              style: TextStyle(
                fontFamily: 'Rajdhani',
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                color: isSelected ? accentColor : AppColors.darkTextSub,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final bool badge;
  final Color accentColor;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.accentColor,
    required this.onTap,
    this.badge = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 80,
        height: 64,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: isSelected ? accentColor.withOpacity(0.2) : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: isSelected
                        ? [BoxShadow(color: accentColor.withOpacity(0.3), blurRadius: 10)]
                        : null,
                  ),
                  child: Icon(
                    icon,
                    size: 20,
                    color: isSelected ? accentColor : AppColors.darkTextSub,
                  ),
                ),
                if (badge)
                  Positioned(
                    top: -2, right: -2,
                    child: Container(
                      width: 8, height: 8,
                      decoration: BoxDecoration(
                        color: AppColors.connected,
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: AppColors.connected.withOpacity(0.6), blurRadius: 4)],
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Rajdhani',
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                color: isSelected ? accentColor : AppColors.darkTextSub,
              ),
            ),
          ],
        ),
      ),
    );
  }
}