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
# AUDIO ENGINE (JustAudio + AudioService + ExoPlayer)
# =========================================================
-keep class com.ryanheise.just_audio.** { *; }
-keep class com.ryanheise.audio_session.** { *; }
-keep class com.ryanheise.just_audio_background.** { *; }
-keep class com.ryanheise.audioservice.** { *; }

# ⚠️ THE FIX: PREVENT SILENT CRASHES IN RELEASE ⚠️
-keep class com.google.android.exoplayer2.** { *; }
-keep class androidx.media3.** { *; }
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod

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
# IGNORE HARMLESS WARNINGS
# =========================================================
-dontwarn com.google.android.play.core.**
-dontwarn io.flutter.embedding.engine.deferredcomponents.**
