import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// The Google Play upload key lives outside git: android/key.properties points
// at android/upload-keystore.jks (see docs/release.md, "Android / Google Play").
// Without the file, release builds fall back to the debug key so `flutter run
// --release` still works on any machine; those builds can't go to Play.
val keystorePropertiesFile = rootProject.file("key.properties")
val hasUploadKey = keystorePropertiesFile.exists()
val keystoreProperties = Properties().apply {
    if (hasUploadKey) keystorePropertiesFile.inputStream().use { load(it) }
}

fun uploadKey(name: String): String =
    keystoreProperties.getProperty(name)?.takeIf { it.isNotBlank() }
        ?: throw GradleException("android/key.properties has no $name (see docs/release.md)")

android {
    namespace = "com.obertagame.oberta"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.obertagame.oberta"
        // Flutter's defaults: min 24 (Android 7), target 36 (Play wants 35+).
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // versionCode is the +N build number of pubspec.yaml, shared with iOS
        // and the desktop builds; versionName is the x.y.z before it.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasUploadKey) {
            create("release") {
                keyAlias = uploadKey("keyAlias")
                keyPassword = uploadKey("keyPassword")
                // Relative to android/app, as in Flutter's docs: ../upload-keystore.jks.
                storeFile = file(uploadKey("storeFile"))
                storePassword = uploadKey("storePassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName(if (hasUploadKey) "release" else "debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
