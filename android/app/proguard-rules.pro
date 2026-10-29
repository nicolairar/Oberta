# Extra R8 rules for the release build (Flutter adds this file on its own).
# Plugins bring their own rules; this covers what they miss.

# Dart that calls Kotlin over JNI (package:jni, and shared_preferences_android
# 2.5 with Pigeon JNI) finds classes and methods by name and JNI signature.
# The plugins keep their own classes, but those signatures and package:jni's
# coroutine glue also name Kotlin stdlib types: if R8 renames or drops them,
# the lookup fails at startup (NoSuchMethodError on
# SharedPreferencesAsyncApiRegistrar.getAll, ClassNotFoundException on
# CoroutineSingletons) and the settings never open. These are all the Kotlin
# types the Dart bindings name (grep the plugins' lib/ for 'kotlin/').
-keep class kotlin.Unit { *; }
-keep class kotlin.Result { *; }
-keep class kotlin.Result$Failure { *; }
-keep class kotlin.coroutines.Continuation { *; }
-keep class kotlin.coroutines.intrinsics.** { *; }
-keep class kotlin.jvm.internal.DefaultConstructorMarker { *; }
-keep class kotlin.enums.EnumEntries { *; }
