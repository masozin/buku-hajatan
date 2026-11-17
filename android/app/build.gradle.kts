import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Plugin google-services HANYA dipakai bila file google-services.json sudah
// ada di folder ini (diunduh Mark dari Firebase Console). Tanpa file itu
// build tetap jalan, dan aplikasi menampilkan layar "Firebase belum
// dikonfigurasi" — lihat lib/screens/belum_konfigurasi.dart.
if (file("google-services.json").exists()) {
    apply(plugin = "com.google.gms.google-services")
}

// Konfigurasi tanda tangan RILIS (Batch 22): dibaca dari
// android/key.properties — file lokal pembuat rilis, TIDAK ikut
// git (sudah di-.gitignore; lihat key.properties.example). Selama
// file itu belum dibuat, build rilis tetap memakai kunci debug
// supaya alur lama tidak rusak; begitu ada, semua build rilis
// otomatis bertanda tangan keystore tersebut — kunci yang sama
// inilah yang membuat pembaruan bisa dipasang menimpa versi lama.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "id.my.ozinsq.bukuhajatan"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "id.my.ozinsq.bukuhajatan"
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
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String?
            keyPassword = keystoreProperties["keyPassword"] as String?
            storeFile = keystoreProperties["storeFile"]?.let { file(it) }
            storePassword = keystoreProperties["storePassword"] as String?
        }
    }

    buildTypes {
        release {
            // Batch 22: keystore rilis bila android/key.properties
            // sudah dibuat; sebelum itu kunci debug (perilaku lama,
            // supaya `flutter run --release` tetap jalan).
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
