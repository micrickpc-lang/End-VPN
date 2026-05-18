// ===================================================
// Оставь свои ключи сюда
// ===================================================
class AppConfig {
  // Remnawave
  static const String remnawaveBaseUrl = 'https://panel.kaban4ik.ru';
  static const String remnawaveToken =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1dWlkIjoiZWY3OWNiOWEtMWIzNS00NzczLWE5ZDEtMTYyMGJlYTY3ZTQxIiwidXNlcm5hbWUiOm51bGwsInJvbGUiOiJBUEkiLCJpYXQiOjE3NzY0NTk2NDAsImV4cCI6MTA0MTYzNzMyNDB9.R9A5CSci5b-97LLi_PMQf0rlgE2hESp0y_I0ZLxhSYY';

  // ЮKassa
  static const String yookassaShopId = '1330608';
  static const String yookassaSecretKey =
      'REDACTED_PAYMENT_SECRET';

  // Bot API
  static const String botApiUrl = 'https://app.kaban4ik.ru';

  // Deep link — приложение открывается по этому URL после оплаты
  static const String paymentReturnUrl = 'endvpn://payment/success';
  static const String paymentReturnUrlScheme = 'endvpn';

  // Планы подписки (совпадают с TARIFFS в config.py бота)
  static const List<SubscriptionPlan> plans = [
    SubscriptionPlan(
      id: '1m',
      label: '1 месяц',
      days: 30,
      price: 497,
      priceStr: '497₽',
    ),
    SubscriptionPlan(
      id: '3m',
      label: '3 месяца',
      days: 90,
      price: 1042,
      priceStr: '1042₽',
      badge: '−30%',
    ),
    SubscriptionPlan(
      id: '6m',
      label: '6 месяцев',
      days: 180,
      price: 2083,
      priceStr: '2083₽',
      badge: '−30%',
    ),
    SubscriptionPlan(
      id: '12m',
      label: '1 год',
      days: 365,
      price: 4167,
      priceStr: '4167₽',
      badge: '−30%',
    ),
  ];
}

class SubscriptionPlan {
  final String id;
  final String label;
  final int days;
  final int price;
  final String priceStr;
  final String? badge;

  const SubscriptionPlan({
    required this.id,
    required this.label,
    required this.days,
    required this.price,
    required this.priceStr,
    this.badge,
  });
}
