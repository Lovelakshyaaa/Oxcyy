# =========================================================
# FLUTTER WRAPPERS
# =========================================================
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# =========================================================
# AUDIO ENGINE (JustAudio + AudioService)
# =========================================================
-keep class com.ryanheise.just_audio.** { *; }
-keep class com.ryanheise.audio_session.** { *; }
-keep class com.ryanheise.just_audio_background.** { *; }
-keep class com.ryanheise.audioservice.** { *; }

# =========================================================
# LOCAL MUSIC & STORAGE
# =========================================================
-keep class com.lucasjosino.on_audio_query.** { *; }

# =========================================================
# ANDROID MEDIA UTILS
# =========================================================
-keep class android.support.v4.media.** { *; }
-keep class androidx.media.** { *; }

# =========================================================
# PREVENT R8 STRIPPING GENERATED PLUGINS
# =========================================================
-keep class io.flutter.plugins.GeneratedPluginRegistrant { *; }

# =========================================================
# ⚠️ THE FIX FOR YOUR ERROR ⚠️
# Tell R8 to ignore missing Play Store classes
# =========================================================
-dontwarn com.google.android.play.core.**
-dontwarn io.flutter.embedding.engine.deferredcomponents.**
