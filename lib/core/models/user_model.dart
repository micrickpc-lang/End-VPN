class UserModel {
  final String uuid;
  final String username;
  final String subscriptionUrl;
  final DateTime? expireAt;
  final int trafficLimitBytes;
  final int usedTrafficBytes;
  final bool isActive;
  final String subscriptionType;
  final int clickerBalance;

  UserModel({
    required this.uuid,
    required this.username,
    required this.subscriptionUrl,
    this.expireAt,
    required this.trafficLimitBytes,
    required this.usedTrafficBytes,
    required this.isActive,
    required this.subscriptionType,
    this.clickerBalance = 0,
  });

  bool get isFree => subscriptionType == 'free';
  bool get isPaid => subscriptionType == 'paid';
  int get daysLeft => expireAt == null ? 0 : expireAt!.difference(DateTime.now()).inDays;
  double get trafficUsedRatio => trafficLimitBytes == 0 ? 0 : usedTrafficBytes / trafficLimitBytes;
  double get trafficUsedGB => usedTrafficBytes / (1024 * 1024 * 1024);
  double get trafficLimitGB => trafficLimitBytes / (1024 * 1024 * 1024);

  /// Mock для запуска без API
  factory UserModel.mock() {
    return UserModel(
      uuid: 'mock-uuid-0000',
      username: 'demo_user',
      subscriptionUrl: '',
      expireAt: null,
      trafficLimitBytes: 10 * 1024 * 1024 * 1024,
      usedTrafficBytes: 2 * 1024 * 1024 * 1024,
      isActive: true,
      subscriptionType: 'free',
      clickerBalance: 0,
    );
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final trafficLimit = (json['trafficLimitBytes'] as num?)?.toInt() ?? 10 * 1024 * 1024 * 1024;
    final traffic = (json['userTraffic'] as Map<String, dynamic>?) ?? {};
    final usedTraffic = (traffic['usedTrafficBytes'] as num?)?.toInt()
        ?? (json['usedTrafficBytes'] as num?)?.toInt()
        ?? 0;
    final expireRaw = json['expireAt'];

    // Определяем тип подписки по скватам
    final squads = (json['activeInternalSquads'] as List?) ?? [];
    const paidSquadUuid = '833414d4-ca2d-47c0-87da-24d6b38a9f20';
    final isPaid = squads.any((s) => (s as Map)['uuid'] == paidSquadUuid);

    // Баланс кликера из description
    final description = json['description'] as String? ?? '';
    final clickMatch = RegExp(r'clicks:(\d+)').firstMatch(description);
    final clicks = int.tryParse(clickMatch?.group(1) ?? '0') ?? 0;

    return UserModel(
      uuid: json['uuid'] as String? ?? '',
      username: json['username'] as String? ?? 'user',
      subscriptionUrl: json['subscriptionUrl'] as String? ?? '',
      expireAt: expireRaw != null ? DateTime.tryParse(expireRaw.toString()) : null,
      trafficLimitBytes: trafficLimit,
      usedTrafficBytes: usedTraffic,
      isActive: json['status'] == 'ACTIVE',
      subscriptionType: isPaid ? 'paid' : 'free',
      clickerBalance: clicks,
    );
  }

  UserModel copyWith({
    String? uuid,
    String? username,
    String? subscriptionUrl,
    DateTime? expireAt,
    int? trafficLimitBytes,
    int? usedTrafficBytes,
    bool? isActive,
    String? subscriptionType,
    int? clickerBalance,
  }) {
    return UserModel(
      uuid: uuid ?? this.uuid,
      username: username ?? this.username,
      subscriptionUrl: subscriptionUrl ?? this.subscriptionUrl,
      expireAt: expireAt ?? this.expireAt,
      trafficLimitBytes: trafficLimitBytes ?? this.trafficLimitBytes,
      usedTrafficBytes: usedTrafficBytes ?? this.usedTrafficBytes,
      isActive: isActive ?? this.isActive,
      subscriptionType: subscriptionType ?? this.subscriptionType,
      clickerBalance: clickerBalance ?? this.clickerBalance,
    );
  }
}
