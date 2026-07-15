import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:endvpn/core/config/app_config.dart';
import 'package:endvpn/core/models/user_model.dart';
import 'package:endvpn/core/services/payment_service.dart';
import 'package:endvpn/core/services/remnawave_service.dart';
import 'package:endvpn/shared/theme/app_theme.dart';
import 'package:endvpn/shared/widgets/glass_card.dart';
import 'package:endvpn/features/profile/presentation/pages/settings_page.dart';

class ProfilePage extends StatefulWidget {
  final UserModel user;
  final Color accentColor;
  final void Function(UserModel) onUserUpdated;
  const ProfilePage({
    super.key,
    required this.user,
    required this.accentColor,
    required this.onUserUpdated,
  });

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> with WidgetsBindingObserver {
  int _selectedPlan = 1;
  bool _paymentLoading = false;
  bool _paymentChecking = false;
  bool _statsRefreshing = false;
  Timer? _statsSyncTimer;
  int _versionTapCount = 0;

  int? _tgId;
  String? _tgUsername;
  final _storage = const FlutterSecureStorage();
  final _plans = AppConfig.plans;

  late UserModel _user;

  static const _adminTgId = 5046046819;

  bool get _showInfinity => _user.isFree;
  bool get _isAdmin => _tgId == _adminTgId;
  String get _adminLabel =>
      _tgUsername == null || _tgUsername!.isEmpty ? 'ADMIN' : '@$_tgUsername';

  Color get _accentColor => widget.accentColor;
  Color get _planColor => _showInfinity ? AppColors.connected : _accentColor;

  String _friendlyError(Object e) {
    if (e is DioException) {
      final code = e.response?.statusCode;
      if (code == 404) {
        return 'Remnawave user not found';
      }
      if (code == 401 || code == 403) {
        return 'Remnawave API access denied';
      }
      if (code != null) return 'Remnawave error $code';
      return 'Remnawave connection error';
    }
    final text = e.toString().replaceFirst('Exception: ', '');
    return text.length > 90 ? '${text.substring(0, 90)}...' : text;
  }

  String get _planDisplayName => _user.isFree ? 'FREE' : 'PREMIUM';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _user = widget.user;
    _loadAdminAuth();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPendingPayment();
      _refreshUserStats();
    });
    _statsSyncTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _refreshUserStats(),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _statsSyncTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPendingPayment();
      _refreshUserStats();
    }
  }

  Future<void> _refreshUserStats() async {
    if (_statsRefreshing || _user.uuid.isEmpty) return;
    _statsRefreshing = true;
    try {
      final updated = await RemnawaveService().refreshUser(_user.uuid);
      if (!mounted) return;
      final changed = updated.trafficLimitBytes != _user.trafficLimitBytes ||
          updated.usedTrafficBytes != _user.usedTrafficBytes ||
          updated.subscriptionType != _user.subscriptionType ||
          updated.isActive != _user.isActive ||
          updated.expireAt != _user.expireAt;
      if (!changed) return;
      setState(() => _user = updated);
      widget.onUserUpdated(updated);
    } catch (_) {
    } finally {
      _statsRefreshing = false;
    }
  }

  Future<void> _checkPendingPayment() async {
    if (_paymentChecking || !await PaymentService().hasPendingPayment()) return;
    _paymentChecking = true;
    try {
      final payment = await PaymentService().checkPendingPayment();
      if (!payment.success) return;

      final anonUuid = await RemnawaveService().getSavedAnonUuid();
      UserModel updated;
      if (anonUuid == _user.uuid) {
        updated = await RemnawaveService().getOrCreateAnonUser();
      } else {
        final savedTgId = await RemnawaveService().getSavedTgId();
        final tgId = int.tryParse(savedTgId ?? '');
        if (tgId == null) return;
        updated = await RemnawaveService().getOrCreateUserByTgId(tgId);
      }
      if (!mounted) return;
      setState(() => _user = updated);
      widget.onUserUpdated(updated);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Оплата прошла. Подписка активирована.'),
          backgroundColor: AppColors.connected,
        ),
      );
    } finally {
      _paymentChecking = false;
    }
  }

  @override
  void didUpdateWidget(ProfilePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.user != oldWidget.user && widget.user != _user) {
      setState(() => _user = widget.user);
    }
  }

  Future<void> _loadAdminAuth() async {
    final id = await _storage.read(key: 'tg_id');
    final username = await _storage.read(key: 'tg_username');
    if (id != null && mounted) {
      setState(() {
        _tgId = int.tryParse(id);
        _tgUsername = username;
      });
    }
  }

  void _onVersionTap() {
    _versionTapCount++;
    if (_versionTapCount >= 7) {
      _versionTapCount = 0;
      _showCodeDialog();
    }
  }

  Future<void> _adminLogout() async {
    await _storage.delete(key: 'tg_id');
    await _storage.delete(key: 'tg_username');
    if (mounted) {
      setState(() {
        _tgId = null;
        _tgUsername = null;
      });
    }
  }

  Future<void> _openSupport() async {
    final telegramUri = Uri.parse('tg://resolve?domain=EndVPN_support');
    final webUri = Uri.https('t.me', '/EndVPN_support');

    try {
      if (await launchUrl(telegramUri, mode: LaunchMode.externalApplication)) {
        return;
      }
    } catch (_) {}

    await launchUrl(webUri, mode: LaunchMode.externalApplication);
  }

  void _showCodeDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _CodeInputSheet(
        onSuccess: (tgId, username) async {
          await _storage.write(key: 'tg_id', value: tgId.toString());
          await _storage.write(key: 'tg_username', value: username);
          RemnawaveService().init();
          await RemnawaveService().saveTgId(tgId);
          if (mounted) {
            setState(() {
              _tgId = tgId;
              _tgUsername = username;
            });
          }
        },
      ),
    );
  }

  void _showPromoDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _PromoInputSheet(
        onActivate: (code) async {
          String? uuid = await RemnawaveService().getSavedAnonUuid();
          if (uuid == null || uuid.isEmpty) {
            uuid = await RemnawaveService().getSavedUuid();
          }
          if (uuid == null || uuid.isEmpty) {
            throw Exception('UUID not found');
          }
          final updatedUser =
              await RemnawaveService().applyPromoCode(uuid, code);
          if (mounted) {
            setState(() => _user = updatedUser);
            widget.onUserUpdated(updatedUser);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('🎉 Промокод активирован!'),
                backgroundColor: AppColors.connected,
              ),
            );
          }
        },
      ),
    );
  }

  void _openSettings() {
    Navigator.push(
        context, MaterialPageRoute(builder: (_) => const SettingsPage()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: LiquidBackground(
        child: Stack(
          children: [
            SafeArea(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                children: [
                  const SizedBox(height: 16),
                  _buildHeader(),
                  const SizedBox(height: 24),
                  _buildSubscriptionCard(),
                  const SizedBox(height: 16),
                  _buildTrafficCard(),
                  if (_showInfinity) ...[
                    const SizedBox(height: 16),
                    _buildAdBanner()
                  ],
                  const SizedBox(height: 24),
                  _buildUpgradeSection(),
                  const SizedBox(height: 24),
                  _buildMenuItems(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.22),
                  blurRadius: 22,
                  offset: const Offset(0, 10))
            ],
          ),
          child: Center(
              child: Icon(
            _showInfinity ? Icons.person_rounded : Icons.verified_rounded,
            color: Colors.white,
            size: 26,
          )),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _showInfinity ? 'Пользователь' : 'Premium',
              style: const TextStyle(
                  fontFamily: 'Rajdhani',
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.darkText),
            ),
            Row(children: [
              Container(
                  width: 6,
                  height: 6,
                  decoration:
                      BoxDecoration(shape: BoxShape.circle, color: _planColor)),
              const SizedBox(width: 6),
              Text(_isAdmin ? _adminLabel : _planDisplayName,
                  style: TextStyle(
                      fontFamily: 'SpaceMono',
                      fontSize: 10,
                      letterSpacing: 1.5,
                      color: _planColor)),
              if (_isAdmin) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                        color: AppColors.warning.withValues(alpha: 0.4)),
                  ),
                  child: const Text('ADMIN',
                      style: TextStyle(
                          fontFamily: 'SpaceMono',
                          fontSize: 7,
                          color: AppColors.warning,
                          letterSpacing: 1)),
                ),
              ],
            ]),
          ],
        ),
        const Spacer(),
        GlassCard(
          blur: 0,
          borderRadius: 12,
          padding: const EdgeInsets.all(10),
          onTap: _openSettings,
          child: const Icon(Icons.settings_rounded,
              color: AppColors.darkTextSub, size: 20),
        ),
      ],
    ).animate().fadeIn(duration: 500.ms).slideX(begin: -0.1, end: 0);
  }

  Widget _buildSubscriptionCard() {
    return NeonGlassCard(
      glowColor: _planColor,
      glowIntensity: 1.0,
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('ПОДПИСКА',
              style: TextStyle(
                  fontFamily: 'SpaceMono',
                  fontSize: 10,
                  color: AppColors.darkTextSub,
                  letterSpacing: 2)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _planColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _planColor.withValues(alpha: 0.4)),
            ),
            child: Text(_planDisplayName,
                style: TextStyle(
                    fontFamily: 'SpaceMono',
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                    color: _planColor)),
          ),
        ]),
        const SizedBox(height: 16),
        if (_showInfinity) ...[
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('∞',
                style: TextStyle(
                    fontFamily: 'Rajdhani',
                    fontSize: 56,
                    fontWeight: FontWeight.w700,
                    color: _planColor,
                    height: 1)),
            const SizedBox(width: 10),
            const Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: Text('БЕСПЛАТНО',
                  style: TextStyle(
                      fontFamily: 'SpaceMono',
                      fontSize: 11,
                      color: AppColors.darkTextSub,
                      letterSpacing: 2)),
            ),
            const Spacer(),
            const Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('РЕКЛАМА',
                  style: TextStyle(
                      fontFamily: 'SpaceMono',
                      fontSize: 9,
                      color: AppColors.darkTextSub,
                      letterSpacing: 1.5)),
              SizedBox(height: 4),
              Text('ВКЛЮЧЕНА',
                  style: TextStyle(
                      fontFamily: 'SpaceMono',
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.warning)),
            ]),
          ]),
        ] else ...[
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('${_user.daysLeft}',
                style: TextStyle(
                    fontFamily: 'Rajdhani',
                    fontSize: 56,
                    fontWeight: FontWeight.w700,
                    color: _planColor,
                    height: 1)),
            const SizedBox(width: 8),
            const Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: Text('ДНЕЙ',
                  style: TextStyle(
                      fontFamily: 'SpaceMono',
                      fontSize: 13,
                      color: AppColors.darkTextSub,
                      letterSpacing: 2)),
            ),
            const Spacer(),
            if (_user.expireAt != null)
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                const Text('ИСТЕКАЕТ',
                    style: TextStyle(
                        fontFamily: 'SpaceMono',
                        fontSize: 9,
                        color: AppColors.darkTextSub,
                        letterSpacing: 1.5)),
                const SizedBox(height: 4),
                Text(
                  '${_user.expireAt!.day.toString().padLeft(2, '0')}.${_user.expireAt!.month.toString().padLeft(2, '0')}.${_user.expireAt!.year}',
                  style: const TextStyle(
                      fontFamily: 'SpaceMono',
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.darkText),
                ),
              ]),
          ]),
        ],
      ]),
    )
        .animate(delay: 100.ms)
        .fadeIn(duration: 500.ms)
        .slideY(begin: 0.1, end: 0);
  }

  Widget _buildTrafficCard() {
    final used = _user.trafficUsedGB.toStringAsFixed(1);
    final limitStr = _user.trafficLimitBytes == 0
        ? '∞'
        : '${_user.trafficLimitGB.toStringAsFixed(0)}GB';
    final ratio = _user.trafficLimitBytes == 0
        ? 0.0
        : _user.trafficUsedRatio.clamp(0.0, 1.0);
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('ТРАФИК',
              style: TextStyle(
                  fontFamily: 'SpaceMono',
                  fontSize: 10,
                  color: AppColors.darkTextSub,
                  letterSpacing: 2)),
          const Spacer(),
          Text('$used / $limitStr',
              style: const TextStyle(
                  fontFamily: 'SpaceMono',
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.darkText)),
        ]),
        const SizedBox(height: 14),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 8,
            backgroundColor: AppColors.darkBorder,
            valueColor: AlwaysStoppedAnimation(
                ratio > 0.8 ? AppColors.crimson : _accentColor),
          ),
        ),
        const SizedBox(height: 8),
        Row(children: [
          Text(
            _user.trafficLimitBytes == 0
                ? 'Безлимит'
                : '${((1 - ratio) * 100).toStringAsFixed(0)}% осталось',
            style: const TextStyle(
                fontFamily: 'SpaceMono',
                fontSize: 10,
                color: AppColors.darkTextSub),
          ),
          if (_showInfinity) ...[
            const Spacer(),
            Text('Обновляется каждый месяц',
                style: TextStyle(
                    fontFamily: 'SpaceMono',
                    fontSize: 9,
                    color: _planColor.withValues(alpha: 0.7))),
          ],
        ]),
      ]),
    ).animate(delay: 150.ms).fadeIn(duration: 500.ms);
  }

  Widget _buildAdBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.darkBorder),
        color: Colors.white.withValues(alpha: 0.03),
      ),
      child: Row(children: [
        Icon(Icons.campaign_rounded,
            color: AppColors.darkTextSub.withValues(alpha: 0.4), size: 18),
        const SizedBox(width: 10),
        Text('РЕКЛАМА · AdMob баннер здесь',
            style: TextStyle(
                fontFamily: 'SpaceMono',
                fontSize: 9,
                color: AppColors.darkTextSub.withValues(alpha: 0.4),
                letterSpacing: 1)),
      ]),
    ).animate(delay: 170.ms).fadeIn(duration: 400.ms);
  }

  Widget _buildUpgradeSection() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text(
          _showInfinity ? 'УБРАТЬ РЕКЛАМУ' : 'ПРОДЛИТЬ ПОДПИСКУ',
          style: const TextStyle(
              fontFamily: 'SpaceMono',
              fontSize: 10,
              color: AppColors.darkTextSub,
              letterSpacing: 2),
        ),
        if (_showInfinity) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.neonBlue.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
              border:
                  Border.all(color: AppColors.neonBlue.withValues(alpha: 0.3)),
            ),
            child: const Text('+ 150GB',
                style: TextStyle(
                    fontFamily: 'SpaceMono',
                    fontSize: 8,
                    color: AppColors.neonBlue,
                    letterSpacing: 1)),
          ),
        ],
        if (_isAdmin) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
              border:
                  Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
            ),
            child: const Text('ADMIN BYPASS',
                style: TextStyle(
                    fontFamily: 'SpaceMono',
                    fontSize: 8,
                    color: AppColors.warning,
                    letterSpacing: 1)),
          ),
        ],
      ]),
      const SizedBox(height: 12),
      GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 2.2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        children: List.generate(_plans.length, (i) {
          final plan = _plans[i];
          final selected = _selectedPlan == i;
          return RepaintBoundary(
            child: GestureDetector(
              onTap: () {
                if (_selectedPlan != i) setState(() => _selectedPlan = i);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                curve: Curves.easeOutCubic,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: selected
                      ? _accentColor.withValues(alpha: 0.16)
                      : Colors.white.withValues(alpha: 0.055),
                  border: Border.all(
                    color: selected
                        ? _accentColor.withValues(alpha: 0.8)
                        : AppColors.darkBorder,
                    width: selected ? 2 : 1,
                  ),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                              color: _accentColor.withValues(alpha: 0.2),
                              blurRadius: 12)
                        ]
                      : null,
                ),
                child: Row(children: [
                  Expanded(
                      child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (plan.badge != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1),
                          margin: const EdgeInsets.only(bottom: 3),
                          decoration: BoxDecoration(
                            color: AppColors.warning.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(plan.badge!,
                              style: const TextStyle(
                                  fontFamily: 'SpaceMono',
                                  fontSize: 7,
                                  color: AppColors.warning)),
                        ),
                      Text(plan.label,
                          style: TextStyle(
                              fontFamily: 'Rajdhani',
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: selected
                                  ? _accentColor
                                  : AppColors.darkText)),
                    ],
                  )),
                  Text(plan.priceStr,
                      style: TextStyle(
                          fontFamily: 'SpaceMono',
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color:
                              selected ? _accentColor : AppColors.darkTextSub)),
                ]),
              ),
            ),
          );
        }),
      ),
      const SizedBox(height: 16),
      GestureDetector(
        onTap: _paymentLoading ? null : _handlePayment,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            gradient: _isAdmin
                ? LinearGradient(colors: [
                    AppColors.warning,
                    AppColors.warning.withValues(alpha: 0.7)
                  ])
                : LinearGradient(colors: [
                    _accentColor,
                    _accentColor.withValues(alpha: 0.7)
                  ]),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                  color: (_isAdmin ? AppColors.warning : _accentColor)
                      .withValues(alpha: 0.35),
                  blurRadius: 20)
            ],
          ),
          child: Center(
            child: _paymentLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : Text(
                    _isAdmin ? 'АКТИВИРОВАТЬ [ADMIN]' : 'ОПЛАТИТЬ',
                    style: const TextStyle(
                        fontFamily: 'Rajdhani',
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 2),
                  ),
          ),
        ),
      ),
    ]).animate(delay: 200.ms).fadeIn(duration: 500.ms);
  }

  Future<void> _handlePayment() async {
    setState(() => _paymentLoading = true);
    try {
      final plan = _plans[_selectedPlan];
      String? uuid = await RemnawaveService().getSavedAnonUuid();
      if (uuid == null || uuid.isEmpty) {
        uuid = await RemnawaveService().getSavedUuid();
      }
      if (uuid == null || uuid.isEmpty) {
        throw Exception('UUID устройства не найден');
      }
      final ok =
          await PaymentService().startPayment(deviceUuid: uuid, plan: plan);
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Ошибка открытия платёжной страницы'),
              backgroundColor: AppColors.crimson),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Ошибка: ${_friendlyError(e)}'),
              backgroundColor: AppColors.crimson),
        );
      }
    } finally {
      if (mounted) setState(() => _paymentLoading = false);
    }
  }

  Widget _buildMenuItems() {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: GlassCard(
          blur: 0,
          borderRadius: 14,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          onTap: _openSupport,
          child: Row(children: [
            const Icon(Icons.support_agent_rounded,
                color: AppColors.darkTextSub, size: 20),
            const SizedBox(width: 14),
            const Text('Поддержка',
                style: TextStyle(
                    fontFamily: 'Rajdhani',
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.darkText)),
            const Spacer(),
            Icon(Icons.chevron_right_rounded,
                color: AppColors.darkTextSub.withValues(alpha: 0.5), size: 18),
          ]),
        ),
      ),
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: GlassCard(
          blur: 0,
          borderRadius: 14,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          onTap: _showPromoDialog,
          child: Row(children: [
            const Icon(Icons.local_offer_rounded,
                color: AppColors.darkTextSub, size: 20),
            const SizedBox(width: 14),
            const Text('Промокод',
                style: TextStyle(
                    fontFamily: 'Rajdhani',
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.darkText)),
            const Spacer(),
            Icon(Icons.chevron_right_rounded,
                color: AppColors.darkTextSub.withValues(alpha: 0.5), size: 18),
          ]),
        ),
      ),
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: GlassCard(
          blur: 0,
          borderRadius: 14,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          onTap: () {},
          child: Row(children: [
            const Icon(Icons.share_rounded,
                color: AppColors.darkTextSub, size: 20),
            const SizedBox(width: 14),
            const Text('Поделиться приложением',
                style: TextStyle(
                    fontFamily: 'Rajdhani',
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.darkText)),
            const Spacer(),
            Icon(Icons.chevron_right_rounded,
                color: AppColors.darkTextSub.withValues(alpha: 0.5), size: 18),
          ]),
        ),
      ),
      GestureDetector(
        onTap: _onVersionTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Center(
            child: Text(
              'EndVPN v1.0.0',
              style: TextStyle(
                  fontFamily: 'SpaceMono',
                  fontSize: 10,
                  color: AppColors.darkTextSub.withValues(alpha: 0.3),
                  letterSpacing: 1),
            ),
          ),
        ),
      ),
      if (_isAdmin)
        GlassCard(
          blur: 0,
          borderRadius: 14,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          onTap: _adminLogout,
          child: Row(children: [
            const Icon(Icons.logout_rounded,
                color: AppColors.crimson, size: 20),
            const SizedBox(width: 14),
            const Text('Выйти (Admin)',
                style: TextStyle(
                    fontFamily: 'Rajdhani',
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.crimson)),
            const Spacer(),
            Icon(Icons.chevron_right_rounded,
                color: AppColors.darkTextSub.withValues(alpha: 0.5), size: 18),
          ]),
        ),
    ]).animate(delay: 300.ms).fadeIn(duration: 500.ms);
  }
}

class _PromoInputSheet extends StatefulWidget {
  final Future<void> Function(String code) onActivate;
  const _PromoInputSheet({required this.onActivate});

  @override
  State<_PromoInputSheet> createState() => _PromoInputSheetState();
}

class _PromoInputSheetState extends State<_PromoInputSheet> {
  final _controller = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final code = _controller.text.trim().toUpperCase();
    if (code.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await widget.onActivate(code);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e is DioException && e.response?.statusCode == 404
              ? 'Неверный промокод'
              : 'Ошибка активации';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            decoration: const BoxDecoration(
              color: Color(0xFF0F0F20),
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              border:
                  Border(top: BorderSide(color: Color(0xFF1E1E40), width: 1)),
            ),
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                    child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                      color: const Color(0xFF1E1E40),
                      borderRadius: BorderRadius.circular(2)),
                )),
                const Icon(Icons.local_offer_rounded,
                    color: AppColors.neonBlue, size: 40),
                const SizedBox(height: 12),
                const Text('ПРОМОКОД',
                    style: TextStyle(
                        fontFamily: 'SpaceMono',
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.neonBlue,
                        letterSpacing: 2)),
                const SizedBox(height: 8),
                const Text('Введите промокод для активации подписки',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontFamily: 'Rajdhani',
                        fontSize: 14,
                        color: AppColors.darkTextSub,
                        height: 1.5)),
                const SizedBox(height: 24),
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _error != null
                          ? AppColors.crimson
                          : AppColors.neonBlue.withValues(alpha: 0.3),
                      width: 1.5,
                    ),
                    color: const Color(0xFF0A0A18),
                  ),
                  child: TextField(
                    controller: _controller,
                    autofocus: true,
                    enabled: !_loading,
                    textInputAction: TextInputAction.done,
                    textAlign: TextAlign.center,
                    textCapitalization: TextCapitalization.characters,
                    style: const TextStyle(
                        fontFamily: 'SpaceMono',
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.neonBlue,
                        letterSpacing: 4),
                    decoration: const InputDecoration(
                      hintText: 'XXXXXXXX',
                      hintStyle: TextStyle(
                          color: AppColors.darkTextSub,
                          letterSpacing: 4,
                          fontSize: 18),
                      border: InputBorder.none,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    ),
                    onSubmitted: (_) => _submit(),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(_error!,
                      style: const TextStyle(
                          fontFamily: 'SpaceMono',
                          fontSize: 11,
                          color: AppColors.crimson)),
                ],
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: _loading ? null : _submit,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [
                        AppColors.neonBlue,
                        AppColors.neonBlue.withValues(alpha: 0.7)
                      ]),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                            color: AppColors.neonBlue.withValues(alpha: 0.3),
                            blurRadius: 20)
                      ],
                    ),
                    child: Center(
                      child: _loading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Text('АКТИВИРОВАТЬ',
                              style: TextStyle(
                                  fontFamily: 'Rajdhani',
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  letterSpacing: 2)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CodeInputSheet extends StatefulWidget {
  final void Function(int tgId, String username) onSuccess;
  const _CodeInputSheet({required this.onSuccess});

  @override
  State<_CodeInputSheet> createState() => _CodeInputSheetState();
}

class _CodeInputSheetState extends State<_CodeInputSheet> {
  final _controllers = List.generate(6, (_) => TextEditingController());
  final _focuses = List.generate(6, (_) => FocusNode());
  bool _loading = false;
  String? _error;

  String get _code => _controllers.map((c) => c.text).join();

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focuses) {
      f.dispose();
    }
    super.dispose();
  }

  void _onDigit(int index, String value) {
    if (value.length == 6) {
      for (int i = 0; i < 6; i++) {
        _controllers[i].text = value[i];
      }
      _focuses[5].requestFocus();
      _submit();
      return;
    }
    if (value.isNotEmpty && index < 5) _focuses[index + 1].requestFocus();
    if (value.isNotEmpty && index == 5) _submit();
  }

  Future<void> _submit() async {
    final code = _code;
    if (code.length < 6) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 8),
      ));
      final resp = await dio
          .post('${AppConfig.botApiUrl}/auth/code', data: {'code': code});
      final data = resp.data as Map<String, dynamic>;
      if (data['ok'] == true) {
        final tgId = data['tg_id'] as int;
        final username = data['username'] as String? ?? '';
        widget.onSuccess(tgId, username);
        if (mounted) Navigator.pop(context);
      } else {
        setState(() => _error = 'Неверный код');
        _clearCode();
      }
    } catch (e) {
      setState(() => _error = 'Ошибка. Проверьте соединение.');
      _clearCode();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _clearCode() {
    for (final c in _controllers) {
      c.clear();
    }
    _focuses[0].requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            decoration: const BoxDecoration(
              color: Color(0xFF0F0F20),
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              border:
                  Border(top: BorderSide(color: Color(0xFF1E1E40), width: 1)),
            ),
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                    child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                      color: const Color(0xFF1E1E40),
                      borderRadius: BorderRadius.circular(2)),
                )),
                const Icon(Icons.admin_panel_settings_rounded,
                    color: AppColors.warning, size: 40),
                const SizedBox(height: 12),
                const Text('ADMIN',
                    style: TextStyle(
                        fontFamily: 'SpaceMono',
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.warning,
                        letterSpacing: 2)),
                const SizedBox(height: 8),
                const Text('Введите код из бота @EndurVPN_bot (/code)',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontFamily: 'Rajdhani',
                        fontSize: 14,
                        color: AppColors.darkTextSub,
                        height: 1.5)),
                const SizedBox(height: 28),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                      6,
                      (i) => Container(
                            width: 46,
                            height: 54,
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _error != null
                                    ? AppColors.crimson
                                    : _controllers[i].text.isNotEmpty
                                        ? AppColors.warning
                                        : const Color(0xFF1E1E40),
                                width: 2,
                              ),
                              color: const Color(0xFF0A0A18),
                            ),
                            child: TextField(
                              controller: _controllers[i],
                              focusNode: _focuses[i],
                              textAlign: TextAlign.center,
                              keyboardType: TextInputType.number,
                              maxLength: i == 0 ? 6 : 1,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly
                              ],
                              style: const TextStyle(
                                  fontFamily: 'SpaceMono',
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.warning),
                              decoration: const InputDecoration(
                                  counterText: '', border: InputBorder.none),
                              onChanged: (v) => _onDigit(i, v),
                            ),
                          )),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!,
                      style: const TextStyle(
                          fontFamily: 'SpaceMono',
                          fontSize: 11,
                          color: AppColors.crimson)),
                ],
                const SizedBox(height: 24),
                GestureDetector(
                  onTap: _loading ? null : _submit,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [
                        AppColors.warning,
                        AppColors.warning.withValues(alpha: 0.7)
                      ]),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                            color: AppColors.warning.withValues(alpha: 0.3),
                            blurRadius: 20)
                      ],
                    ),
                    child: Center(
                      child: _loading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Text('ВОЙТИ',
                              style: TextStyle(
                                  fontFamily: 'Rajdhani',
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  letterSpacing: 2)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
