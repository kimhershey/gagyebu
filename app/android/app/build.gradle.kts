plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// 릴리스 서명 키는 환경 변수로 받는다. CI가 저장소 비밀값에서 채운다(.github/workflows의 "서명 키 준비").
// 키 파일 경로(ANDROID_KEYSTORE_PATH)가 없으면 디버그 키로 서명한다. 그래야 비밀값이 없는 포크와
// 개발자의 PC에서도 release 빌드가 돈다.
val releaseKeystorePath: String? = System.getenv("ANDROID_KEYSTORE_PATH")?.takeIf { it.isNotBlank() }

// 키 파일은 있는데 나머지 값이 빠졌으면 멈춘다. 조용히 디버그 키로 넘어가면 서명이 다른 APK가
// 배포되어, 받은 사람이 기존 앱 위에 설치하지 못한다.
fun requiredSigningEnv(name: String): String =
    System.getenv(name)?.takeIf { it.isNotEmpty() }
        ?: throw GradleException("ANDROID_KEYSTORE_PATH가 있는데 환경 변수 $name 이(가) 비어 있다.")

android {
    namespace = "io.github.kimhershey.gagyebu"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "io.github.kimhershey.gagyebu"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // Android 10 이상(설계안의 최소 사양)
        minSdk = 29
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        releaseKeystorePath?.let { keystorePath ->
            create("release") {
                storeFile = file(keystorePath)
                storePassword = requiredSigningEnv("ANDROID_KEYSTORE_PASSWORD")
                keyAlias = requiredSigningEnv("ANDROID_KEY_ALIAS")
                keyPassword = requiredSigningEnv("ANDROID_KEY_PASSWORD")
            }
        }
    }

    buildTypes {
        release {
            // 서명 키를 받았으면 그 키로, 아니면 디버그 키로 서명한다(`flutter run --release`도 그대로 돈다).
            signingConfig = signingConfigs.findByName("release") ?: signingConfigs.getByName("debug")
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
