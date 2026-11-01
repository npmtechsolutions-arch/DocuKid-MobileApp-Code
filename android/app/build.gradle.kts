import java.io.FileInputStream
import java.util.Base64
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// ADS.md §7: the AdMob App ID comes from --dart-define=ADMOB_APP_ID_ANDROID=…
// (Flutter passes dart-defines to Gradle base64-encoded). Without it, debug
// and profile builds use Google's sample App ID (test ads only); release
// builds are refused (see the release gate below).
val dartDefines: Map<String, String> = (project.findProperty("dart-defines") as String?)
    ?.split(",")
    ?.mapNotNull {
        val kv = String(Base64.getDecoder().decode(it)).split("=", limit = 2)
        if (kv.size == 2) kv[0] to kv[1] else null
    }
    ?.toMap() ?: emptyMap()
val admobAppId = dartDefines["ADMOB_APP_ID_ANDROID"]?.takeIf { it.isNotBlank() }
    ?: "ca-app-pub-3940256099942544~3347511713"

// Release gate (same rules as lib/core/ads/release_check.dart): a release
// build needs the real AdMob App ID and every Phase A ad unit ID.
val samplePublishers = setOf("3940256099942544", "1234567890123456")
val phaseAUnitKeys = listOf(
    "ADMOB_NATIVE_HOME", "ADMOB_NATIVE_RESULT", "ADMOB_NATIVE_HISTORY", "ADMOB_NATIVE_DETAILS",
    "ADMOB_BANNER_SETTINGS", "ADMOB_INTERSTITIAL_DONE", "ADMOB_REWARDED_ADFREE",
    "ADMOB_BANNER_MAIN", "ADMOB_BANNER_TOOLS", "ADMOB_BANNER_INFO",
)
// Banner keys accept "off" (no slot built), ADR-035.
val bannerKeys = setOf("ADMOB_BANNER_SETTINGS", "ADMOB_BANNER_MAIN", "ADMOB_BANNER_TOOLS", "ADMOB_BANNER_INFO")
fun admobReleaseProblems(): List<String> {
    val problems = mutableListOf<String>()
    fun check(key: String, shape: Regex, kind: String) {
        val v = dartDefines[key]?.trim().orEmpty()
        val m = shape.matchEntire(v)
        when {
            v.isEmpty() -> problems += "$key is missing: set your real AdMob $kind."
            m == null -> problems += "$key is not a valid AdMob $kind (\"$v\")."
            m.groupValues[1] in samplePublishers -> problems += "$key is a Google sample/test ID (\"$v\"): use your own AdMob $kind."
        }
    }
    check("ADMOB_APP_ID_ANDROID", Regex("ca-app-pub-(\\d{16})~\\d{10}"), "App ID (ca-app-pub-…~…)")
    phaseAUnitKeys
        // A banner key set to "off": no slot, nothing to check.
        .filterNot { it in bannerKeys && dartDefines[it]?.trim()?.lowercase() == "off" }
        .forEach {
            val kind = if (it in bannerKeys) "ad unit ID (ca-app-pub-…/…), or \"off\" to hide this banner" else "ad unit ID (ca-app-pub-…/…)"
            check(it, Regex("ca-app-pub-(\\d{16})/\\d{10}"), kind)
        }
    return problems
}
// Play upload key (RELEASE §2): android/key.properties (gitignored, never
// committed) names a keystore kept outside the repo. Without it a release
// build is refused rather than signed with the debug key, which Play rejects.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile.exists()) FileInputStream(keystorePropertiesFile).use { load(it) }
}
fun uploadKeyProblems(): List<String> {
    if (!keystorePropertiesFile.exists()) {
        return listOf("android/key.properties is missing: create your Play upload key (docs/RELEASE.md §2.1).")
    }
    val missing = listOf("storeFile", "storePassword", "keyAlias", "keyPassword")
        .filter { keystoreProperties.getProperty(it).isNullOrBlank() }
    if (missing.isNotEmpty()) return listOf("android/key.properties lacks: ${missing.joinToString()}.")
    val store = rootProject.file(keystoreProperties.getProperty("storeFile"))
    return if (store.exists()) emptyList() else listOf("The keystore in android/key.properties (storeFile) doesn't exist.")
}

tasks.configureEach {
    if (name == "preReleaseBuild") {
        doFirst {
            val keyProblems = uploadKeyProblems()
            if (keyProblems.isNotEmpty()) {
                throw GradleException(
                    "Release build refused: no Play upload key.\n" + keyProblems.joinToString("\n") { "  • $it" },
                )
            }
            val problems = admobReleaseProblems()
            if (problems.isNotEmpty()) {
                throw GradleException(
                    "Release build refused: AdMob IDs are not ready.\n" +
                        problems.joinToString("\n") { "  • $it" } +
                        "\nPass your real IDs with --dart-define (or --dart-define-from-file); " +
                        "see docs/DocuKit_Ad_Map.xlsx, sheet \"Ad units\".",
                )
            }
        }
    }
}

android {
    namespace = "com.npmtechsolutions.docukit"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // flutter_local_notifications (1.5 reminders) needs java.time on API 26+ builds.
        isCoreLibraryDesugaringEnabled = true
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

    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("upload") {
                storeFile = rootProject.file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // The Play upload key (RELEASE §2.1); without key.properties the
            // release gate above refuses the build before anything is signed.
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("upload")
            } else {
                signingConfigs.getByName("debug")
            }
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Text recognition: Latin comes with the plugin; Devanagari is added here.
    // Both bundled, so OCR works offline from the first use (ADR-045).
    implementation("com.google.mlkit:text-recognition-devanagari:16.0.1")
    // flutter_local_notifications 22.3.3 README: desugaring library version.
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    // LaunchTheme's AppCompat parent (local_auth). Already resolved transitively at
    // this version; pinned so the theme doesn't depend on another library's choice.
    implementation("androidx.appcompat:appcompat:1.6.1")
}
