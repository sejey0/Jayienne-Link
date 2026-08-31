# Flutter ProGuard / R8 Rules

# WorkManager & Room Database Protection
-keep class androidx.work.** { *; }
-keep class * extends androidx.work.ListenableWorker {
    public <init>(...);
}
-keep class * extends androidx.work.Worker {
    public <init>(...);
}
-keep class * extends androidx.room.RoomDatabase {
    public <init>();
}
-keep class androidx.work.impl.WorkDatabase_Impl {
    public <init>();
}
-keep class androidx.work.impl.WorkDatabase {
    *;
}

# AndroidX Startup / InitializationProvider
-keep class androidx.startup.** { *; }

# Flutter Wrapper and Plugins
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# Audio & Media Plugins
-dontwarn com.google.android.exoplayer2.**
-dontwarn androidx.media3.**
