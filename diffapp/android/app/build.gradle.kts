plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "dev.minamidenshiimanaka.diffapp"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

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
            abiFilters += listOf("arm64-v8a")
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
}

flutter {
    source = "../.."
}

dependencies {
    // TensorFlow Lite ランタイム
    implementation("org.tensorflow:tensorflow-lite:2.14.0")
}
