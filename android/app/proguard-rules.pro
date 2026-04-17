# Flutter ProGuard Rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Google Mobile Ads
-keep class com.google.android.gms.ads.** { *; }
-keep class com.google.ads.** { *; }

# Firebase
-keep class com.google.firebase.** { *; }

# ML Kit Text Recognition (Fix R8 missing classes)
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
-keep class com.google.mlkit.vision.text.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_text_common.** { *; }

# Syncfusion
-keep class com.syncfusion.** { *; }

# Play Store Split Install (Missing classes fix)
-dontwarn com.google.android.play.core.**

# Keep members of specific classes that might be accessed via reflection
-keepclassmembers class * {
    @com.google.android.gms.common.annotation.KeepName *;
}
-keepnames class * implements android.os.Parcelable {
    public static final android.os.Parcelable$Creator *;
}
