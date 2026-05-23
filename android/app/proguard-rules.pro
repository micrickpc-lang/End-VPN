# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# sing-box VPN плагин
-keep class io.nekohasekai.** { *; }
-keep class com.example.endvpn.** { *; }

# Dio / OkHttp
-dontwarn okhttp3.**
-dontwarn okio.**
-keep class okhttp3.** { *; }

# Kotlin
-dontwarn kotlin.**
-keep class kotlin.** { *; }
-keep class kotlinx.** { *; }

# Keep enums
-keepclassmembers enum * { *; }

# Предотвращаем удаление нативных методов
-keepclasseswithmembernames class * {
    native <methods>;
}