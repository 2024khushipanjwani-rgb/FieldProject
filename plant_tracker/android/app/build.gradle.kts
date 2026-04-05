import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

val localProperties = Properties()
val localPropertiesFile = rootProject.file("local.properties")
if (localPropertiesFile.exists()) {
    localPropertiesFile.inputStream().use { localProperties.load(it) }
}

val flutterVersionCode = localProperties.getProperty("flutter.versionCode") ?: "1"
val flutterVersionName = localProperties.getProperty("flutter.versionName") ?: "1.0"

android {
    namespace = "com.example.plant_tracker"
    compileSdk = 36 // Standard for modern Flutter

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
    }

    kotlinOptions {
        jvmTarget = "1.8"
    }

    defaultConfig {
        applicationId = "com.example.plant_tracker"
        minSdk = flutter.minSdkVersion
        targetSdk = 36
        versionCode = flutterVersionCode.toInt()
        versionName = flutterVersionName
        multiDexEnabled = true // <--- ADD THIS LINE
    }
    buildTypes {
        getByName("release") {
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation(platform("com.google.firebase:firebase-bom:33.0.0"))
    implementation("com.google.firebase:firebase-analytics")
    implementation("com.google.firebase:firebase-auth")
    implementation("com.google.firebase:firebase-database")
}
// Force Gradle to put the APK where Flutter expects it
tasks.whenTaskAdded {
    if (name.contains("assembleDebug")) {
        doLast {
            val buildDir = layout.buildDirectory.asFile.get()
            val oldApk = File(buildDir, "outputs/apk/debug/app-debug.apk")
            val newDir = File(project.rootDir.parentFile, "build/app/outputs/flutter-apk/")

            if (oldApk.exists()) {
                newDir.mkdirs()
                oldApk.copyTo(File(newDir, "app-debug.apk"), overwrite = true)
            }
        }
    }
}
