class AppConfig {
  static const String remnawaveBaseUrl = 'https://panel.kaban4ik.ru';

  static const String botApiUrl = 'https://panel.kaban4ik.ru/payment';

  static const String paymentReturnUrl = 'endvpn://payment/success';
  static const String paymentReturnUrlScheme = 'endvpn';

  static const List<SubscriptionPlan> plans = [
    SubscriptionPlan(
      id: '1m',
      label: '1 месяц',
      days: 30,
      price: 224,
      priceStr: '224₽',
    ),
    SubscriptionPlan(
      id: '3m',
      label: '3 месяца',
      days: 90,
      price: 566,
      priceStr: '566₽',
      badge: '−30%',
    ),
    SubscriptionPlan(
      id: '6m',
      label: '6 месяцев',
      days: 180,
      price: 1079,
      priceStr: '1079₽',
      badge: '−30%',
    ),
    SubscriptionPlan(
      id: '12m',
      label: '1 год',
      days: 365,
      price: 1979,
      priceStr: '1979₽',
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
