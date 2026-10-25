# ML Kit specific suppressions
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
-keep class com.google.mlkit.** { *; }

# Flutter Engine & Plugins
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.**

# Firebase
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# Camera / CameraX
-keep class androidx.camera.** { *; }
-dontwarn androidx.camera.**

# SQLite3 / Drift native libs
-keep class org.sqlite.** { *; }
-keep class com.moonturns.sqlite3.** { *; }
-dontwarn org.sqlite.**

# Security & Biometrics
-keep class androidx.security.crypto.** { *; }
-keep class androidx.biometric.** { *; }
