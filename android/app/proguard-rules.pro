# Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# JUST_AUDIO & AUDIO_SERVICE (The Fix)
-keep class com.ryanheise.just_audio.** { *; }
-keep class com.ryanheise.audio_session.** { *; }
-keep class com.ryanheise.just_audio_background.** { *; }
-keep class com.ryanheise.audioservice.** { *; }

# ON_AUDIO_QUERY (Fixes Local Art/Music)
-keep class com.lucasjosino.on_audio_query.** { *; }

# MEDIA SESSION
-keep class android.support.v4.media.** { *; }
-keep class androidx.media.** { *; }

# PREVENT R8 FROM STRIPPING GENERATED PLUGINS
-keep class io.flutter.plugins.GeneratedPluginRegistrant { *; }
