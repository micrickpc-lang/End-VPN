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
import 'package:endvpn/shared/widgets/liquid_glass_button.dart';

class AppShell extends StatefulWidget {
  final UserModel? user;
  final Color accentColor;
  final bool liquidGlass;
  const AppShell({
    super.key,
    this.user,
    required this.accentColor,
    this.liquidGlass = true,
  });

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _currentIndex = 0;
  UserModel? _user;
  bool _userLoading = true;

  late Color _accentColor;
  bool _userUpdatedLocally = false;

  final ValueNotifier<int> _activeTab = ValueNotifier<int>(0);

  @override
  void initState() {
    super.initState();
    _accentColor = widget.accentColor;
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

  void _activateTab(int index) {
    setState(() => _currentIndex = index);
    _activeTab.value = index;
    if (index == 2) _refreshUser();
  }

  Future<void> _switchTab(int index) async {
    if (index == _currentIndex) return;
    _activateTab(index);
  }

  void _onUserUpdated(UserModel u) {
    setState(() {
      _user = u;
      _userUpdatedLocally = true;
    });
  }

  @override
  void dispose() {
    _activeTab.dispose();
    super.dispose();
  }

  List<Widget> _tabChildren(UserModel user) => [
        HomePage(liquidGlass: widget.liquidGlass),
        ClickerPage(activeTab: _activeTab),
        ProfilePage(
          key: const ValueKey('profile_stable'),
          user: user,
          accentColor: _accentColor,
          onUserUpdated: _onUserUpdated,
          activeTab: _activeTab,
        ),
      ];

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
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    if (isDesktop) {
      return _DesktopShell(
        currentIndex: _currentIndex,
        accentColor: _accentColor,
        onTap: _switchTab,
        child: IndexedStack(
          index: _currentIndex,
          children: _tabChildren(user),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: IndexedStack(
        index: _currentIndex,
        children:
            _tabChildren(user).map((w) => _KeepAliveTab(child: w)).toList(),
      ),
      bottomNavigationBar: _WarpNavBar(
        currentIndex: _currentIndex,
        accentColor: _accentColor,
        onTap: _switchTab,
      ),
    );
  }
}

class _KeepAliveTab extends StatefulWidget {
  final Widget child;
  const _KeepAliveTab({required this.child});

  @override
  State<_KeepAliveTab> createState() => _KeepAliveTabState();
}

class _KeepAliveTabState extends State<_KeepAliveTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

class _DesktopShell extends StatelessWidget {
  final int currentIndex;
  final Color accentColor;
  final ValueChanged<int> onTap;
  final Widget child;

  const _DesktopShell({
    required this.currentIndex,
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
  final Color accentColor;
  final ValueChanged<int> onTap;

  const _DesktopNav({
    required this.currentIndex,
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
  final Color accentColor;
  final VoidCallback onTap;

  const _DesktopNavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.accentColor,
    required this.onTap,
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
              Icon(icon,
                  color: selected ? accentColor : AppColors.darkTextSub,
                  size: 22),
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

class _WarpNavBar extends StatefulWidget {
  final int currentIndex;
  final Color accentColor;
  final ValueChanged<int> onTap;

  const _WarpNavBar({
    required this.currentIndex,
    required this.accentColor,
    required this.onTap,
  });

  @override
  State<_WarpNavBar> createState() => _WarpNavBarState();
}

class _WarpNavBarState extends State<_WarpNavBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _slideController;
  double _visualIndex = 0;
  double _dragStartIndex = 0;
  double _dragDistance = 0;
  bool _dragging = false;

  @override
  void initState() {
    super.initState();
    _visualIndex = widget.currentIndex.toDouble();
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
  }

  @override
  void didUpdateWidget(covariant _WarpNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_dragging && oldWidget.currentIndex != widget.currentIndex) {
      _animateLensTo(widget.currentIndex.toDouble());
    }
  }

  Future<void> _animateLensTo(double target) async {
    _slideController.stop();
    final start = _visualIndex;
    final animation = Tween<double>(begin: start, end: target).animate(
      CurvedAnimation(
        parent: _slideController,
        curve: Curves.easeOutBack,
      ),
    );
    void update() {
      if (mounted) setState(() => _visualIndex = animation.value);
    }

    animation.addListener(update);
    _slideController.value = 0;
    await _slideController.forward();
    animation.removeListener(update);
    if (mounted) setState(() => _visualIndex = target);
  }

  void _onDragStart(DragStartDetails details) {
    _slideController.stop();
    _dragging = true;
    _dragDistance = 0;
    _dragStartIndex = widget.currentIndex.toDouble();
  }

  void _onDragUpdate(DragUpdateDetails details, double itemWidth) {
    _dragDistance += details.primaryDelta ?? 0;
    setState(() {
      _visualIndex =
          (_dragStartIndex + _dragDistance / itemWidth).clamp(0.0, 2.0);
    });
  }

  void _onDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    var target = _dragStartIndex.round();
    if (_dragDistance > 22 || velocity > 180) {
      target++;
    } else if (_dragDistance < -22 || velocity < -180) {
      target--;
    } else {
      target = _visualIndex.round();
    }
    target = target.clamp(0, 2);
    _dragging = false;
    widget.onTap(target);
    _animateLensTo(target.toDouble());
  }

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }

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
            child: LayoutBuilder(
              builder: (context, constraints) {
                final itemWidth = constraints.maxWidth / 3;
                const lensSize = 42.0;
                final lensLeft =
                    itemWidth * (_visualIndex + 0.5) - lensSize / 2;
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragStart: _onDragStart,
                  onHorizontalDragUpdate: (details) =>
                      _onDragUpdate(details, itemWidth),
                  onHorizontalDragEnd: _onDragEnd,
                  child: Stack(
                    children: [
                      Positioned(
                        left: lensLeft,
                        top: 3,
                        width: lensSize,
                        height: lensSize,
                        child: IgnorePointer(
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              LiquidGlassButton(
                                size: lensSize,
                                stateColor: widget.accentColor,
                                stateMix: 0.82,
                                pulse: _dragging ? 0.18 : 0,
                                fallback: Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: widget.accentColor
                                        .withValues(alpha: 0.16),
                                  ),
                                ),
                                child: const SizedBox.shrink(),
                              ),
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 160),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withValues(
                                      alpha: _dragging ? 0.055 : 0.035),
                                  border: Border.all(
                                    color: widget.accentColor.withValues(
                                        alpha: _dragging ? 0.95 : 0.82),
                                    width: _dragging ? 2.0 : 1.6,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: widget.accentColor.withValues(
                                          alpha: _dragging ? 0.38 : 0.28),
                                      blurRadius: _dragging ? 18 : 13,
                                      spreadRadius: _dragging ? 1.2 : 0.4,
                                    ),
                                    BoxShadow(
                                      color:
                                          Colors.white.withValues(alpha: 0.16),
                                      blurRadius: 2,
                                      offset: const Offset(-1, -1),
                                    ),
                                  ],
                                ),
                              ),
                              Positioned(
                                left: 8,
                                right: 8,
                                top: 5,
                                height: 8,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(20),
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.white.withValues(alpha: 0.42),
                                        Colors.white.withValues(alpha: 0.04),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          _NavItem(
                            icon: Icons.shield_rounded,
                            label: 'VPN',
                            isSelected: widget.currentIndex == 0,
                            accentColor: widget.accentColor,
                            onTap: () => widget.onTap(0),
                          ),
                          _NavItem(
                            icon: Icons.touch_app_rounded,
                            label: 'Клик',
                            isSelected: widget.currentIndex == 1,
                            accentColor: widget.accentColor,
                            onTap: () => widget.onTap(1),
                          ),
                          _NavItem(
                            icon: Icons.person_rounded,
                            label: 'Профиль',
                            isSelected: widget.currentIndex == 2,
                            accentColor: widget.accentColor,
                            onTap: () => widget.onTap(2),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
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
  final Color accentColor;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          height: 64,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 42,
                height: 42,
                child: Center(
                  child: AnimatedScale(
                    scale: isSelected ? 1.08 : 1,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutBack,
                    child: Icon(
                      icon,
                      size: 20,
                      color: isSelected ? accentColor : AppColors.darkTextSub,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 1),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 250),
                style: TextStyle(
                  fontFamily: 'Rajdhani',
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                  color: isSelected ? accentColor : AppColors.darkTextSub,
                ),
                child: Text(label),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
