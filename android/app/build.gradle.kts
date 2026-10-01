import java.util.Properties
import java.io.FileInputStream
import java.io.File
import com.google.gms.googleservices.GoogleServicesTask

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

val releaseRequested = gradle.startParameter.taskNames.any {
    it.contains("release", ignoreCase = true) || it.equals("build", ignoreCase = true)
}
// Derive isolation from the explicit Dart target: integration tests can
// never build the production package, even if the caller forgets a QA flag.
val requestedTarget = providers.gradleProperty("target").orNull
check(requestedTarget?.contains("flutter_test_listener.") != true) {
    "Unsafe Android test bootstrap: use tool/test_device.ps1 with a verified prebuilt QA APK, not flutter test -d."
}
val integrationTestRoot = rootProject.file("../integration_test").canonicalFile.toPath()
val deviceQa = requestedTarget?.let {
    val targetFile = File(it)
    val resolvedTarget = if (targetFile.isAbsolute) targetFile else rootProject.file("../$it")
    resolvedTarget.canonicalFile.toPath().startsWith(integrationTestRoot)
} == true || providers.gradleProperty("fintrackQa").orNull == "true"
if (releaseRequested) {
    check(keystorePropertiesFile.exists()) { "Release signing requires android/key.properties. Debug signing is never used for releases." }
    listOf("keyAlias", "keyPassword", "storeFile", "storePassword").forEach { key ->
        check(!keystoreProperties.getProperty(key).isNullOrBlank()) { "Missing release signing property: $key" }
    }
    check(file(keystoreProperties.getProperty("storeFile")).isFile) { "Release keystore file does not exist." }
    check(keystoreProperties.getProperty("keyAlias") != "androiddebugkey") { "The debug key cannot sign a release." }
}

android {
    namespace = "com.vishalnakum.fintrack"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.vishalnakum.fintrack"
        if (deviceQa) applicationIdSuffix = ".qa"
        if (deviceQa && requestedTarget != null) {
            val targetFile = File(requestedTarget)
            val resolvedTarget = if (targetFile.isAbsolute) targetFile else rootProject.file("../$requestedTarget")
            resValue("string", "fintrack_qa_test_target", rootProject.file("..").canonicalFile.toPath()
                .relativize(resolvedTarget.canonicalFile.toPath()).toString().replace('\\', '/'))
        }
        manifestPlaceholders["appLabel"] = if (deviceQa) "FinTrack QA" else "FinTrack"
        manifestPlaceholders["qaCleartext"] = deviceQa.toString()
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties["keyAlias"] as String?
                keyPassword = keystoreProperties["keyPassword"] as String?
                storeFile = keystoreProperties["storeFile"]?.let { file(it) }
                storePassword = keystoreProperties["storePassword"] as String?
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

if (deviceQa) {
    // The Google plugin assigns its candidates when Android variants are
    // registered; override only afterwards so its default cannot replace QA.
    afterEvaluate {
        tasks.withType<GoogleServicesTask>().configureEach {
            googleServicesJsonFiles.set(listOf(file("src/qa/google-services.json")))
        }
    }
}

flutter {
    source = "../.."
}
