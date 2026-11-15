import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasReleaseKeystore =
    keystorePropertiesFile.exists().also { exists ->
        if (exists) {
            keystoreProperties.load(FileInputStream(keystorePropertiesFile))
        }
    }

android {
    namespace = "com.albatariq.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    // AGP 9 defaults resValues=false; flavors use resValue for app_name.
    buildFeatures {
        resValues = true
    }

    defaultConfig {
        applicationId = "com.albatariq.app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["appLabel"] = "البطريق"
    }

    flavorDimensions += "environment"
    productFlavors {
        create("production") {
            dimension = "environment"
            resValue("string", "app_name", "البطريق")
        }
        create("staging") {
            dimension = "environment"
            applicationIdSuffix = ".staging"
            versionNameSuffix = "-staging"
            resValue("string", "app_name", "البطريق Staging")
        }
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
                val storeTypeProp = keystoreProperties["storeType"] as String?
                if (!storeTypeProp.isNullOrBlank()) {
                    storeType = storeTypeProp
                }
            }
        }
    }

    buildTypes {
        debug {
            manifestPlaceholders["appLabel"] = "البطريق تجريبي"
        }
        release {
            if (hasReleaseKeystore) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }
}

val googleServicesProd = file("google-services.prod.json")
val googleServicesStaging = file("google-services.staging.json")
val googleServicesActive = file("google-services.json")

tasks.configureEach {
    if (!name.contains("GoogleServices")) return@configureEach
    if (!name.contains("Debug")) {
        mustRunAfter(tasks.matching { it.name.contains("GoogleServices") && it.name.contains("Debug") })
    }
    val useStaging = name.contains("Debug")
    doFirst {
        val source = if (useStaging && googleServicesStaging.exists()) {
            googleServicesStaging
        } else {
            googleServicesProd
        }
        if (source.exists()) {
            source.copyTo(googleServicesActive, overwrite = true)
        }
    }
    doLast {
        if (googleServicesProd.exists()) {
            googleServicesProd.copyTo(googleServicesActive, overwrite = true)
        }
    }
}

// نسخة release موقّعة بمفتاح debug تُرفض في Play ولا يمكن تحديثها لاحقاً.
gradle.taskGraph.whenReady {
    if (!hasReleaseKeystore && allTasks.any { it.name.contains("Release") }) {
        throw GradleException(
            "Missing android/key.properties — release builds require the upload keystore.",
        )
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
