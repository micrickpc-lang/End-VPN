import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:endvpn/features/home/presentation/pages/home_page.dart';
import 'package:endvpn/features/clicker/presentation/pages/clicker_page.dart';
import 'package:endvpn/features/profile/presentation/pages/profile_page.dart';
import 'package:endvpn/core/models/user_model.dart';
import 'package:endvpn/core/services/remnawave_service.dart';
import 'package:endvpn/shared/theme/app_theme.dart';
import 'package:endvpn/shared/widgets/glass_card.dart';

class AppShell extends StatefulWidget {
  final UserModel? user;
  final Color accentColor;
  const AppShell({super.key, this.user, required this.accentColor});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with TickerProviderStateMixin {
  int _currentIndex = 0;
  final Set<int> _builtTabs = {0};
  UserModel? _user;
  bool _userLoading = true;
  final bool _vpnConnected = false;

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
        if (mounted) {
          setState(() {
            _user = anonUser;
            _userLoading = false;
          });
        }
        return;
      }
      final user =
          await RemnawaveService().getOrCreateUserByTgId(int.parse(tgIdStr));
      if (mounted) {
        setState(() {
          _user = user;
          _userLoading = false;
        });
      }
    } catch (e) {
      debugPrint('AppShell _loadUser error: $e');
      try {
        final anonUser = await RemnawaveService().getOrCreateAnonUser();
        if (mounted) {
          setState(() {
            _user = anonUser;
            _userLoading = false;
          });
        }
      } catch (_) {
        if (mounted) {
          setState(() {
            _user = UserModel.mock();
            _userLoading = false;
          });
        }
      }
    }
  }

  Future<void> _refreshUser() async {
    if (_userUpdatedLocally) return;
    try {
      final tgIdStr = await RemnawaveService().getSavedTgId();
      UserModel user;
      if (tgIdStr != null) {
        user =
            await RemnawaveService().getOrCreateUserByTgId(int.parse(tgIdStr));
      } else {
        user = await RemnawaveService().getOrCreateAnonUser();
      }
      if (mounted) setState(() => _user = user);
    } catch (_) {}
  }

  Future<void> _switchTab(int index) async {
    if (index == _currentIndex) return;
    await _tabController.reverse();
    setState(() {
      _currentIndex = index;
      _builtTabs.add(index);
    });
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
        body:
            Center(child: CircularProgressIndicator(color: AppColors.neonBlue)),
      );
    }

    final user = _user!;
    final content = _buildCurrentStack(user);
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    if (isDesktop) {
      return _DesktopShell(
        currentIndex: _currentIndex,
        vpnConnected: _vpnConnected,
        accentColor: _accentColor,
        onTap: _switchTab,
        child: content,
      );
    }

    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: content,
      bottomNavigationBar: _WarpNavBar(
        currentIndex: _currentIndex,
        vpnConnected: _vpnConnected,
        accentColor: _accentColor,
        onTap: _switchTab,
      ),
    );
  }

  Widget _buildCurrentStack(UserModel user) {
    return AnimatedBuilder(
      animation: _tabController,
      builder: (context, child) => Opacity(
        opacity: _tabController.value.clamp(0.0, 1.0),
        child: child,
      ),
      child: IndexedStack(
        index: _currentIndex,
        children: List.generate(3, (index) {
          if (!_builtTabs.contains(index)) {
            return const SizedBox.shrink();
          }

          return switch (index) {
            0 => const HomePage(),
            1 => const ClickerPage(),
            _ => ProfilePage(
                key: const ValueKey('profile_stable'),
                user: user,
                accentColor: _accentColor,
                onUserUpdated: _onUserUpdated,
              ),
          };
        }),
      ),
    );
  }
}

class _DesktopShell extends StatelessWidget {
  final int currentIndex;
  final bool vpnConnected;
  final Color accentColor;
  final ValueChanged<int> onTap;
  final Widget child;

  const _DesktopShell({
    required this.currentIndex,
    required this.vpnConnected,
    required this.accentColor,
    required this.onTap,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: LiquidBackground(
        child: SafeArea(
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 22, 0, 22),
                child: _DesktopNav(
                  currentIndex: currentIndex,
                  vpnConnected: vpnConnected,
                  accentColor: accentColor,
                  onTap: onTap,
                ),
              ),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 780),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(34),
                      child: child,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 22),
            ],
          ),
        ),
      ),
    );
  }
}

class _DesktopNav extends StatelessWidget {
  final int currentIndex;
  final bool vpnConnected;
  final Color accentColor;
  final ValueChanged<int> onTap;

  const _DesktopNav({
    required this.currentIndex,
    required this.vpnConnected,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          width: 210,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.18),
                Colors.white.withValues(alpha: 0.08),
                Colors.white.withValues(alpha: 0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.24),
                blurRadius: 28,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.20),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.14)),
                    ),
                    child: Image.asset('assets/images/logo.png',
                        fit: BoxFit.contain),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'END VPN',
                    style: TextStyle(
                      fontFamily: 'Rajdhani',
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.darkText,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              _DesktopNavItem(
                icon: Icons.shield_rounded,
                label: 'VPN',
                selected: currentIndex == 0,
                badge: vpnConnected,
                accentColor: accentColor,
                onTap: () => onTap(0),
              ),
              _DesktopNavItem(
                icon: Icons.touch_app_rounded,
                label: 'Bonus',
                selected: currentIndex == 1,
                accentColor: accentColor,
                onTap: () => onTap(1),
              ),
              _DesktopNavItem(
                icon: Icons.person_rounded,
                label: 'Profile',
                selected: currentIndex == 2,
                accentColor: accentColor,
                onTap: () => onTap(2),
              ),
              const Spacer(),
              Text(
                'Desktop',
                style: TextStyle(
                  fontFamily: 'SpaceMono',
                  fontSize: 10,
                  color: AppColors.darkTextSub.withValues(alpha: 0.75),
                  letterSpacing: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DesktopNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final bool badge;
  final Color accentColor;
  final VoidCallback onTap;

  const _DesktopNavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.accentColor,
    required this.onTap,
    this.badge = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: selected
                ? accentColor.withValues(alpha: 0.16)
                : Colors.white.withValues(alpha: 0.035),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected
                  ? accentColor.withValues(alpha: 0.55)
                  : Colors.white.withValues(alpha: 0.08),
            ),
          ),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(icon,
                      color: selected ? accentColor : AppColors.darkTextSub,
                      size: 22),
                  if (badge)
                    Positioned(
                      top: -3,
                      right: -4,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppColors.connected,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Rajdhani',
                  fontSize: 16,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  color: selected ? accentColor : AppColors.darkText,
                ),
              ),
            ],
          ),
        ),
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
                  Colors.white.withValues(alpha: 0.18),
                  Colors.white.withValues(alpha: 0.08),
                  Colors.white.withValues(alpha: 0.055),
                ],
              ),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.18), width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.24),
                  blurRadius: 26,
                  offset: const Offset(0, 14),
                ),
              ],
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
                    color: isSelected
                        ? Colors.white.withValues(alpha: 0.14)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isSelected
                          ? Colors.white.withValues(alpha: 0.16)
                          : Colors.transparent,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                                color: Colors.black.withValues(alpha: 0.16),
                                blurRadius: 12,
                                offset: const Offset(0, 6))
                          ]
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
                    top: -2,
                    right: -2,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: AppColors.connected,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                              color: AppColors.connected.withValues(alpha: 0.6),
                              blurRadius: 4)
                        ],
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
