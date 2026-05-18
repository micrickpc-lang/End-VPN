import 'dart:ui';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:endvpn/shared/theme/app_theme.dart';

class AuthPage extends StatefulWidget {
  final VoidCallback onAccepted;
  const AuthPage({super.key, required this.onAccepted});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> with SingleTickerProviderStateMixin {
  bool _accepted = false;
  bool _loading = false;
  late AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _proceed() async {
    if (!_accepted || _loading) return;
    setState(() => _loading = true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('tos_accepted', true);
    widget.onAccepted();
  }

  Future<void> _openOferta() async {
    final uri = Uri.parse('https://telegra.ph/PUBLICHNAYA-OFERTA-End-VPN-04-17');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: Stack(
        children: [
          // Background glow
          Positioned(
            top: -100,
            left: -80,
            child: AnimatedBuilder(
              animation: _pulse,
              builder: (_, __) => Container(
                width: 350,
                height: 350,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.neonBlue.withOpacity(0.08 + _pulse.value * 0.04),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -120,
            right: -60,
            child: AnimatedBuilder(
              animation: _pulse,
              builder: (_, __) => Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFFAA44FF).withOpacity(0.06 + _pulse.value * 0.03),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo
                    _buildLogo(),
                    const SizedBox(height: 32),

                    // Title
                    const Text(
                      'Вход в аккаунт',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 28),

                    // ToS Box
                    _buildTosBox(),
                    const SizedBox(height: 20),

                    // Checkbox
                    _buildCheckbox(),
                    const SizedBox(height: 28),

                    // Button
                    _buildButton(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogo() {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, __) => Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [Color(0xFF7B4FFF), Color(0xFFFF4B8B)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF7B4FFF).withOpacity(0.3 + _pulse.value * 0.15),
              blurRadius: 24,
              spreadRadius: 2,
            ),
          ],
        ),
        child: const Icon(
          Icons.shield_rounded,
          color: Colors.white,
          size: 36,
        ),
      ),
    );
  }

  Widget _buildTosBox() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          height: 220,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                child: Text(
                  'УСЛОВИЯ ИСПОЛЬЗОВАНИЯ',
                  style: TextStyle(
                    fontFamily: 'SpaceMono',
                    fontSize: 10,
                    letterSpacing: 2,
                    color: AppColors.darkTextSub,
                  ),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      _TosSection(
                        title: '1. Согласие с условиями',
                        body:
                            'Нажимая кнопку «Согласен», вы подтверждаете, что полностью ознакомлены и согласны с настоящими Правилами, а также с условиями Публичной оферты.',
                      ),
                      SizedBox(height: 12),
                      _TosSection(
                        title: '2. Формат услуги',
                        body:
                            'Сервис предоставляет доступ к вычислительным мощностям и сетевым шлюзам «как есть». Исполнитель не несёт ответственности за перебои в работе, вызванные действиями государственных регуляторов или провайдеров связи.',
                      ),
                      SizedBox(height: 12),
                      _TosSection(
                        title: '3. Запрет на незаконные действия',
                        body:
                            'Категорически запрещено использование ресурсов сервиса для спама, взлома, распространения запрещённого контента или иных действий, нарушающих законодательство.',
                      ),
                      SizedBox(height: 12),
                      _TosSection(
                        title: '4. Запрет на распространение',
                        body:
                            'Запрещается распространение предоставленных услуг или товаров третьим лицам.',
                      ),
                      SizedBox(height: 12),
                      _TosSection(
                        title: '5. Блокировка',
                        body:
                            'Администрация вправе ограничить доступ к сервису без возврата средств при выявлении нарушений правил или подозрительной активности.',
                      ),
                      SizedBox(height: 12),
                      _TosSection(
                        title: '6. Политика платежей',
                        body:
                            'Все транзакции являются добровольными. Порядок возврата средств и условия автоматических продлений регулируются Публичной офертой.',
                      ),
                      SizedBox(height: 12),
                      _TosSection(
                        title: '7. Безопасность',
                        body:
                            'Вы несёте полную ответственность за сохранность ключей доступа и своего аккаунта.',
                      ),
                      SizedBox(height: 12),
                      _TosSection(
                        title: '8. Поддержка',
                        body:
                            'По всем вопросам обращайтесь в официальный чат технической поддержки.',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCheckbox() {
    return GestureDetector(
      onTap: () => setState(() => _accepted = !_accepted),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              color: _accepted
                  ? const Color(0xFF7B4FFF)
                  : Colors.white.withOpacity(0.06),
              border: Border.all(
                color: _accepted
                    ? const Color(0xFF7B4FFF)
                    : Colors.white.withOpacity(0.2),
                width: 1.5,
              ),
              boxShadow: _accepted
                  ? [BoxShadow(color: const Color(0xFF7B4FFF).withOpacity(0.4), blurRadius: 8)]
                  : null,
            ),
            child: _accepted
                ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.darkTextSub,
                  height: 1.4,
                ),
                children: [
                  const TextSpan(text: 'Я прочитал(а) и принимаю условия использования и '),
                  TextSpan(
                    text: 'оферту',
                    style: const TextStyle(
                      color: Color(0xFF7B4FFF),
                      decoration: TextDecoration.underline,
                      decorationColor: Color(0xFF7B4FFF),
                    ),
                    recognizer: TapGestureRecognizer()..onTap = _openOferta,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildButton() {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 250),
      opacity: _accepted ? 1.0 : 0.4,
      child: GestureDetector(
        onTap: _accepted ? _proceed : null,
        child: Container(
          width: double.infinity,
          height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: const LinearGradient(
              colors: [Color(0xFF7B4FFF), Color(0xFFFF4B8B)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            boxShadow: _accepted
                ? [BoxShadow(color: const Color(0xFF7B4FFF).withOpacity(0.4), blurRadius: 16, offset: const Offset(0, 4))]
                : null,
          ),
          child: Center(
            child: _loading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Text(
                    'Продолжить',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      letterSpacing: 0.3,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _TosSection extends StatelessWidget {
  final String title;
  final String body;
  const _TosSection({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.white,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          body,
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.darkTextSub,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}