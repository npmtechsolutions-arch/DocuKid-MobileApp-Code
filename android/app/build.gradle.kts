import java.util.Base64

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// ADS.md §7: the AdMob App ID comes from --dart-define=ADMOB_APP_ID_ANDROID=…
// (Flutter passes dart-defines to Gradle base64-encoded). Without it, Google's
// sample App ID is used, which only serves test ads.
val dartDefines: Map<String, String> = (project.findProperty("dart-defines") as String?)
    ?.split(",")
    ?.mapNotNull {
        val kv = String(Base64.getDecoder().decode(it)).split("=", limit = 2)
        if (kv.size == 2) kv[0] to kv[1] else null
    }
    ?.toMap() ?: emptyMap()
val admobAppId = dartDefines["ADMOB_APP_ID_ANDROID"]?.takeIf { it.isNotBlank() }
    ?: "ca-app-pub-3940256099942544~3347511713"

android {
    namespace = "com.npmtechsolutions.docukit"
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
        // OD-1 (provisional): confirm before the first store upload — it can't change afterwards.
        applicationId = "com.npmtechsolutions.docukit"
        minSdk = 26 // ADR-015
        targetSdk = 36 // Play requirement from 31 Aug 2026
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["admobAppId"] = admobAppId
    }

    buildTypes {
        release {
            // Replace with the Play upload key before release (RELEASE §2, TASKS T6.3).
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }
}

flutter {
    source = "../.."
}
