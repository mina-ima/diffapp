plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "dev.minamidenshiimanaka.diffapp"
    compileSdk = flutter.compileSdkVersion
    // 明示的に必要な NDK バージョンを指定（プラグインの要件に合わせる）
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "dev.minamidenshiimanaka.diffapp"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode()
        versionName = flutter.versionName()

        // ★ Apple Silicon のエミュ用に ABI を arm64 のみに限定（ビルド時間短縮・トラブル回避）
        ndk {
            abiFilters.clear()
            // テスト要件に合わせて arm64-v8a / armeabi-v7a をサポート
            abiFilters += listOf("arm64-v8a", "armeabi-v7a")
        }

        // ★ CMake のフラグ（空でOK。必要になったら追記）
        externalNativeBuild {
            cmake {
                // 例：必要に応じて "-std=c++17" などを追加
                cppFlags += listOf("")
            }
        }
    }

    buildTypes {
        release {
            // デバッグ署名のまま（必要に応じて署名を設定）
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    // ★ CMakeLists.txt へのパスは app/ からの相対で記述
    externalNativeBuild {
        cmake {
            path = file("src/main/cpp/CMakeLists.txt")
        }
    }

    // ★ jniLibs に配置している OpenCV のスタブ .so は strip 対象から除外
    //   （NDK の llvm-strip が "not a valid object file" を出すため）
    packagingOptions {
        doNotStrip("*/arm64-v8a/*.so")
        doNotStrip("*/armeabi-v7a/*.so")
    }
}

flutter {
    source = "../.."
}

dependencies {
    // TensorFlow Lite ランタイム
    implementation("org.tensorflow:tensorflow-lite:2.14.0")
}
