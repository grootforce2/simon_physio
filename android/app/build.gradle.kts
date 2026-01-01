plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

configurations.all {
    exclude(group = "com.google.android.play", module = "feature-delivery")
}
// GF_PLAYCORE_FIX: force Play Core for Flutter deferred components; exclude Play Feature Delivery to avoid duplicate classes
configurations.all {
    exclude(group = "com.google.android.play", module = "feature-delivery")
    exclude(group = "com.google.android.play", module = "asset-delivery")
    exclude(group = "com.google.android.play", module = "app-update")
    exclude(group = "com.google.android.play", module = "review")
} 
// GF_PLAY_DEPS_V2: satisfy Flutter deferred components (PlayStoreDeferredComponentManager) for R8
configurations.all {
    // avoid duplicate class explosions between legacy play:core and new delivery libs
    exclude(group = "com.google.android.play", module = "core")
}


android {
    namespace = "com.simon.physio.simon_physio"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        ndk {
            abiFilters += setOf("armeabi-v7a","arm64-v8a")
        }
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.simon.physio.simon_physio"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

// SIMON_DOCTOR_DISABLE_STRIP
configurations.all {
    exclude(group = "com.google.android.play", module = "feature-delivery")
}
// GF_PLAYCORE_FIX: force Play Core for Flutter deferred components; exclude Play Feature Delivery to avoid duplicate classes
configurations.all {
    exclude(group = "com.google.android.play", module = "feature-delivery")
    exclude(group = "com.google.android.play", module = "asset-delivery")
    exclude(group = "com.google.android.play", module = "app-update")
    exclude(group = "com.google.android.play", module = "review")
} 
// GF_PLAY_DEPS_V2: satisfy Flutter deferred components (PlayStoreDeferredComponentManager) for R8
configurations.all {
    // avoid duplicate class explosions between legacy play:core and new delivery libs
    exclude(group = "com.google.android.play", module = "core")
}


android {
  packaging {
    jniLibs {
      keepDebugSymbols += setOf("**/*.so")
    }
  }
}

// SIMON_DOCTOR_PLAY_FEATURE_DELIVERY
dependencies {
  
    implementation("com.google.android.play:core-common:2.0.4")
configurations.all { exclude(group = "com.google.android.play", module = "core") }
implementation("com.google.android.play:core:1.10.3")
implementation("com.google.android.play:feature-delivery:2.0.1")
}
  
// GF: playcore conflict fix (Flutter deferred components references com.google.android.play.core.*)
// Use ONE Play stack: keep play:core, exclude play:feature-delivery to prevent duplicate classes.
configurations.configureEach {
    exclude(group = "com.google.android.play", module = "feature-delivery")
}