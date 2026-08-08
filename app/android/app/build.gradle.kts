import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// 서명 정보는 저장소에 들어가지 않는다. android/key.properties 에 두고
// .gitignore 가 그 파일과 *.jks 를 막고 있다.
//
// 이 파일이 없으면 릴리스 빌드는 디버그 키로 서명된다 — 개발 중 편의를 위해서다.
// 그 상태의 산출물은 배포하면 안 된다:
//   - Play Console이 거부한다
//   - DEBUGGABLE 이라 앱 내부가 열린다
//   - 나중에 정식 키로 바꾸면 서명이 달라져 업데이트가 막힌다
//     (사용자가 앱을 지우고 새로 깔아야 하고, 저장한 번호도 사라진다)
val keystoreProperties = Properties().apply {
    val file = rootProject.file("key.properties")
    if (file.exists()) file.inputStream().use { load(it) }
}
val hasReleaseKey = keystoreProperties.getProperty("storeFile") != null

android {
    namespace = "com.lottolite.lotto_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Play Console 등록 후 영구 변경 불가 (설계 문서 §13-1).
        // Dart 패키지명(lotto_app)과 별개로 여기서 명시한다.
        applicationId = "com.lottolite.app"
        // 설계 문서 §13-2: Android 8. 국내 사용 기기 대부분을 덮으면서
        // 구형 대응 부담은 지지 않는 선.
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseKey) {
            create("release") {
                // storeFile 경로는 android/ 기준 상대경로로 적는다.
                storeFile = rootProject.file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // key.properties 가 있으면 정식 키로, 없으면 디버그 키로 서명한다.
            // 배포용 산출물을 뽑기 전에 `flutter build apk --release` 로그에
            // 아래 경고가 없는지 확인할 것.
            signingConfig = if (hasReleaseKey) {
                signingConfigs.getByName("release")
            } else {
                logger.warn(
                    "⚠️ android/key.properties 가 없어 릴리스가 디버그 키로 서명된다. " +
                        "배포하면 안 된다."
                )
                signingConfigs.getByName("debug")
            }

            // isMinifyEnabled 는 켜지 않는다. Flutter는 Dart를 이미 AOT로
            // 컴파일하므로 줄어드는 것은 플러그인의 Java/Kotlin 부분뿐이라
            // 이득이 작다. 반면 QR 스캐너가 쓰는 ML Kit은 리플렉션에 의존해
            // 축소하면 깨지기 쉽다. 켜려면 ProGuard 규칙을 갖추고
            // **릴리스 빌드에서 실제로 QR을 찍어본 뒤** 판단할 것.
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
