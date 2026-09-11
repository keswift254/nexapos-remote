import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// key.properties is gitignored and holds real signing secrets - never
// committed. Falls back to debug signing when it's absent (a fresh
// clone on another machine, CI, etc.) rather than failing the build,
// since only real release/Play Store builds need the upload key.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.nexapos.nexapos_mobile"
    compileSdk = 37
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.nexapos.nexapos_mobile"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    // Every release build - direct-download and any future Play Store
    // listing alike - now signs with the one permanent upload key in
    // key.properties. This used to be gated behind NEXAPOS_PLAYSTORE_BUILD
    // so the direct-download/self-update channel kept using whatever
    // debug key happened to already be on real devices, on the theory
    // that switching would break in-place updates for existing installs
    // (Android refuses to install an update signed with a different key
    // than what's already there). That theory held right up until an
    // *unpinned* debug key - regenerated fresh by Gradle whenever the
    // build environment was reset - silently changed multiple times
    // across this app's own release history anyway (1.0.12/13, then
    // 1.0.14-19, then 1.0.20/21, then 1.0.22 onward each got a
    // different signing cert), stranding every real device that
    // happened to update during one of those windows. Pinning to this
    // one permanent, backed-up key is what actually fixes it going
    // forward - the debug key was never actually stable, it just
    // happened to hold for a few releases at a time.
    buildTypes {
        release {
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
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
