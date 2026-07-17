import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:endvpn/core/services/remnawave_service.dart';
import 'package:endvpn/shared/theme/app_theme.dart';
import 'package:endvpn/shared/widgets/glass_card.dart';

class ClickerPage extends StatefulWidget {
  final ValueListenable<int>? activeTab;
  const ClickerPage({super.key, this.activeTab});

  @override
  State<ClickerPage> createState() => _ClickerPageState();
}

class _ClickerPageState extends State<ClickerPage>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  int _coins = 0;
  int _perClick = 1;
  int _passivePerSec = 0;
  double _buttonScale = 1.0;
  final List<_FloatingText> _floatingTexts = [];
  late final AnimationController _shieldPulse;
  bool _loaded = false;
  bool _isVisible = true;

  String? _userUuid;
  int _unsyncedClicks = 0;
  static const _syncThreshold = 50;

  Timer? _passiveTimer;

  Timer? _saveDebounce;
  SharedPreferences? _prefs;

  static const _keyCoins = 'clicker_coins';
  static const _keyPerClick = 'clicker_per_click';
  static const _keyPassive = 'clicker_passive';
  static const _keyPurchased = 'clicker_purchased';

  final List<_Upgrade> _upgrades = [
    const _Upgrade(
        id: 'double',
        label: '×2 за клик',
        cost: 50,
        icon: Icons.bolt_rounded,
        multiplier: 2),
    const _Upgrade(
        id: 'passive1',
        label: '+1/сек',
        cost: 100,
        icon: Icons.auto_awesome_rounded,
        passive: 1),
    const _Upgrade(
        id: 'triple',
        label: '×3 за клик',
        cost: 200,
        icon: Icons.flash_on_rounded,
        multiplier: 3),
    const _Upgrade(
        id: 'passive5',
        label: '+5/сек',
        cost: 500,
        icon: Icons.speed_rounded,
        passive: 5),
  ];
  final Set<String> _purchased = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _shieldPulse = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    widget.activeTab?.addListener(_onActiveTabChanged);
    if (widget.activeTab != null) {
      _isVisible = widget.activeTab!.value == 1;
    }

    _loadState();
  }

  void _onActiveTabChanged() {
    setVisible(widget.activeTab!.value == 1);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _stopPassiveTimer();
      _flushSave();
    } else if (state == AppLifecycleState.resumed && _isVisible) {
      _startPassiveTimer();
    }
  }

  void _startPassiveTimer() {
    if (_passiveTimer?.isActive == true) return;
    if (_passivePerSec <= 0) return;
    _passiveTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _coins += _passivePerSec;
        _unsyncedClicks += _passivePerSec;
      });
      _scheduleSave();
      _maybeSyncRemote();
    });
  }

  void _stopPassiveTimer() {
    _passiveTimer?.cancel();
    _passiveTimer = null;
  }

  void setVisible(bool visible) {
    _isVisible = visible;
    if (visible) {
      _startPassiveTimer();
    } else {
      _stopPassiveTimer();
      _flushSave();
    }
  }

  Future<void> _loadState() async {
    _prefs = await SharedPreferences.getInstance();
    final purchasedList = _prefs!.getStringList(_keyPurchased) ?? [];

    _userUuid = await RemnawaveService().getSavedUuid();

    final localCoins = _prefs!.getInt(_keyCoins) ?? 0;
    int remoteCoins = localCoins;
    if (_userUuid != null) {
      try {
        final fetched = await RemnawaveService().getClickerBalance(_userUuid!);
        remoteCoins = fetched > localCoins ? fetched : localCoins;
      } catch (_) {
        remoteCoins = localCoins;
      }
    }

    if (!mounted) return;
    setState(() {
      _coins = remoteCoins;
      _perClick = _prefs!.getInt(_keyPerClick) ?? 1;
      _passivePerSec = _prefs!.getInt(_keyPassive) ?? 0;
      _purchased.addAll(purchasedList);
      _loaded = true;
    });

    await _prefs!.setInt(_keyCoins, _coins);

    if (_passivePerSec > 0 && _isVisible) _startPassiveTimer();
  }

  void _scheduleSave() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(seconds: 2), _flushSave);
  }

  Future<void> _flushSave() async {
    if (_prefs == null) return;
    await Future.wait([
      _prefs!.setInt(_keyCoins, _coins),
      _prefs!.setInt(_keyPerClick, _perClick),
      _prefs!.setInt(_keyPassive, _passivePerSec),
      _prefs!.setStringList(_keyPurchased, _purchased.toList()),
    ]);
  }

  Future<void> _maybeSyncRemote() async {
    if (_userUuid == null) return;
    if (_unsyncedClicks < _syncThreshold) return;
    _unsyncedClicks = 0;
    try {
      await RemnawaveService().saveClickerBalance(_userUuid!, _coins);
    } catch (_) {}
  }

  Future<void> _forceSyncRemote() async {
    if (_userUuid == null) return;
    _unsyncedClicks = 0;
    try {
      await RemnawaveService().saveClickerBalance(_userUuid!, _coins);
    } catch (_) {}
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.activeTab?.removeListener(_onActiveTabChanged);
    _stopPassiveTimer();
    _saveDebounce?.cancel();
    _flushSave();
    _forceSyncRemote();
    _shieldPulse.dispose();
    super.dispose();
  }

  void _onTap(TapDownDetails details) {
    if (!_loaded) return;
    HapticFeedback.lightImpact();
    setState(() {
      _coins += _perClick;
      _unsyncedClicks += _perClick;
      _buttonScale = 0.92;
      _floatingTexts.add(_FloatingText(
        value: '+$_perClick',
        position: details.localPosition,
        id: UniqueKey(),
      ));
    });

    _scheduleSave();
    _maybeSyncRemote();

    Future.delayed(const Duration(milliseconds: 80), () {
      if (mounted) setState(() => _buttonScale = 1.0);
    });

    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) {
        setState(() => _floatingTexts
            .removeWhere((t) => t.position == details.localPosition));
      }
    });
  }

  void _buyUpgrade(_Upgrade upgrade) {
    if (!_loaded) return;
    if (_coins < upgrade.cost || _purchased.contains(upgrade.id)) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _coins -= upgrade.cost;
      _purchased.add(upgrade.id);
      if (upgrade.multiplier != null) _perClick *= upgrade.multiplier!;
      if (upgrade.passive != null) {
        _passivePerSec += upgrade.passive!;
        if (_passivePerSec > 0 && _isVisible) _startPassiveTimer();
      }
    });
    _flushSave();
    _forceSyncRemote();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: LiquidBackground(
        child: Stack(
          children: [
            if (!_loaded)
              const Center(
                  child: CircularProgressIndicator(color: AppColors.neonBlue))
            else
              SafeArea(
                child: Column(
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 8),
                    _buildStatsBar(),
                    const SizedBox(height: 24),
                    Expanded(child: _buildClickZone()),
                    _buildUpgrades(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Row(
        children: [
          const Text('CLICKER',
              style: TextStyle(
                  fontFamily: 'Rajdhani',
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: AppColors.darkText,
                  letterSpacing: 4)),
          const Spacer(),
          GlassCard(
            borderRadius: 14,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.monetization_on_rounded,
                    color: AppColors.warning, size: 18),
                const SizedBox(width: 6),
                Text(_formatCoins(_coins),
                    style: const TextStyle(
                        fontFamily: 'SpaceMono',
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.warning)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          _MiniStat(
              label: 'ЗА КЛИК',
              value: '×$_perClick',
              color: AppColors.neonBlue),
          const SizedBox(width: 12),
          _MiniStat(
              label: 'В СЕК',
              value: _passivePerSec > 0 ? '+$_passivePerSec' : '--',
              color: AppColors.connected),
        ],
      ).animate().fadeIn(duration: 400.ms),
    );
  }

  Widget _buildClickZone() {
    return RepaintBoundary(
      child: GestureDetector(
        onTapDown: _onTap,
        child: Stack(
          alignment: Alignment.center,
          children: [
            ..._floatingTexts.map((ft) => _FloatingTextWidget(ft: ft)),
            AnimatedScale(
              scale: _buttonScale,
              duration: const Duration(milliseconds: 80),
              child: AnimatedBuilder(
                animation: _shieldPulse,
                builder: (_, __) => Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: [
                      Colors.white.withValues(alpha: 0.24),
                      AppColors.neonBlue
                          .withValues(alpha: 0.10 + _shieldPulse.value * 0.05),
                      Colors.white.withValues(alpha: 0.04),
                    ]),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.26),
                        blurRadius: 36 + _shieldPulse.value * 8,
                        offset: const Offset(0, 18),
                      ),
                    ],
                    border: Border.all(
                      color: Colors.white
                          .withValues(alpha: 0.20 + _shieldPulse.value * 0.06),
                      width: 1,
                    ),
                  ),
                  child: const Icon(Icons.shield_rounded,
                      size: 90, color: AppColors.neonBlue),
                ),
              ),
            ),
            Positioned(
              bottom: 40,
              child: Text('ТАП ЧТОБЫ ДОБЫТЬ МОНЕТЫ',
                  style: TextStyle(
                      fontFamily: 'SpaceMono',
                      fontSize: 10,
                      color: AppColors.darkTextSub.withValues(alpha: 0.6),
                      letterSpacing: 2)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUpgrades() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text('УЛУЧШЕНИЯ',
                style: TextStyle(
                    fontFamily: 'SpaceMono',
                    fontSize: 10,
                    color: AppColors.darkTextSub,
                    letterSpacing: 2)),
          ),
          Row(
            children: _upgrades.map((u) {
              final bought = _purchased.contains(u.id);
              final canAfford = _coins >= u.cost;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => _buyUpgrade(u),
                    child: GlassCard(
                      borderRadius: 14,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 12),
                      borderColor: bought
                          ? AppColors.connected.withValues(alpha: 0.4)
                          : canAfford
                              ? AppColors.neonBlue.withValues(alpha: 0.3)
                              : null,
                      child: Column(children: [
                        Icon(u.icon,
                            color: bought
                                ? AppColors.connected
                                : canAfford
                                    ? AppColors.neonBlue
                                    : AppColors.darkTextSub,
                            size: 22),
                        const SizedBox(height: 6),
                        Text(u.label,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontFamily: 'Rajdhani',
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: bought
                                    ? AppColors.connected
                                    : AppColors.darkText)),
                        const SizedBox(height: 4),
                        Text(bought ? '✓' : '${u.cost}🪙',
                            style: TextStyle(
                                fontFamily: 'SpaceMono',
                                fontSize: 10,
                                color: bought
                                    ? AppColors.connected
                                    : canAfford
                                        ? AppColors.warning
                                        : AppColors.darkTextSub)),
                      ]),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  String _formatCoins(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }
}

class _Upgrade {
  final String id;
  final String label;
  final int cost;
  final IconData icon;
  final int? multiplier;
  final int? passive;
  const _Upgrade({
    required this.id,
    required this.label,
    required this.cost,
    required this.icon,
    this.multiplier,
    this.passive,
  });
}

class _FloatingText {
  final String value;
  final Offset position;
  final Key id;
  const _FloatingText(
      {required this.value, required this.position, required this.id});
}

class _FloatingTextWidget extends StatefulWidget {
  final _FloatingText ft;
  const _FloatingTextWidget({required this.ft});

  @override
  State<_FloatingTextWidget> createState() => _FloatingTextWidgetState();
}

class _FloatingTextWidgetState extends State<_FloatingTextWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _opacity;
  late final Animation<double> _y;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..forward();
    _opacity = Tween(begin: 1.0, end: 0.0)
        .animate(CurvedAnimation(parent: _c, curve: const Interval(0.5, 1.0)));
    _y = Tween(begin: 0.0, end: -60.0)
        .animate(CurvedAnimation(parent: _c, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: widget.ft.position.dx - 20,
      top: widget.ft.position.dy - 80,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => Transform.translate(
          offset: Offset(0, _y.value),
          child: Opacity(
            opacity: _opacity.value,
            child: Text(widget.ft.value,
                style: const TextStyle(
                    fontFamily: 'Rajdhani',
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.neonBlue)),
          ),
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _MiniStat(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      borderRadius: 12,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: const TextStyle(
                  fontFamily: 'SpaceMono',
                  fontSize: 9,
                  color: AppColors.darkTextSub,
                  letterSpacing: 1.5)),
          const SizedBox(width: 8),
          Text(value,
              style: TextStyle(
                  fontFamily: 'SpaceMono',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: color)),
        ],
      ),
    );
  }
}
