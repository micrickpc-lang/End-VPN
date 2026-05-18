# EndVPN v3 — с реальной начинкой

## Что реализовано
- Remnawave API: авто-создание юзера по device fingerprint
- Подписка: FREE навсегда (10GB/мес) + платные планы
- Оплата ЮKassa: открывает браузер → возврат по deep link → авто-активация
- VPN: platform channel для xray-core (мок на desktop, реальный на Android)

## Настройка

### 1. Вставь ключи в lib/core/config/app_config.dart
```dart
static const String yookassaShopId = 'ТВОЙ_SHOP_ID';
static const String yookassaSecretKey = 'ТВОЙ_SECRET_KEY';
```

### 2. pubspec.yaml — замени свой
flutter pub get

### 3. AndroidManifest.xml — добавь deep link
Открой android/app/src/main/AndroidManifest.xml
Внутри тега <activity> добавь содержимое AndroidManifest_PATCH.xml

### 4. Запуск
flutter run

## Цены
- 1 месяц — 97₽
- 3 месяца — 250₽
- 6 месяцев — 495₽
- 1 год — 995₽

## Флоу оплаты
1. Юзер нажимает ОПЛАТИТЬ
2. Приложение создаёт платёж в ЮKassa через API
3. Открывается браузер с формой оплаты
4. После оплаты браузер редиректит на endvpn://payment/success
5. Приложение перехватывает deep link
6. Проверяет статус платежа в ЮKassa
7. Активирует подписку в Remnawave (expireAt + 100GB)
8. UI обновляется — FREE → PREMIUM
