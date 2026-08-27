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
        minSdk = flutter.minSdkVersion
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

    // Play Store builds use the real upload key below - a fresh
    // distribution channel, nothing installed from it yet. The
    // direct-download build published to nexapos-site and installed via
    // this app's own self-update mechanism deliberately keeps using the
    // debug key every existing real install already has - Android
    // refuses to install an update signed with a different key than
    // what's already on the device, so switching it would silently
    // break self-update for every current user.
    //
    // Gated on an explicit env var, NOT on which Gradle task got
    // invoked - gradle.startParameter.taskNames looked like a clean way
    // to tell `flutter build appbundle` (bundleRelease) apart from
    // `flutter build apk` (assembleRelease) automatically, but tested it
    // for real and it did NOT work as expected: a plain `flutter build
    // apk --release` still picked up the upload-key signing. Caught via
    // apksigner before anything got published, not left as a landmine -
    // this explicit opt-in is deliberately impossible to trigger by
    // accident.
    val isPlayStoreBuild = System.getenv("NEXAPOS_PLAYSTORE_BUILD") == "true"

    buildTypes {
        release {
            signingConfig = if (isPlayStoreBuild && keystorePropertiesFile.exists()) {
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
