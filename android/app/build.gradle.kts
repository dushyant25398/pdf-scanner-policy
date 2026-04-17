plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.codewearlabs.pdfscanner"
    compileSdk = 36
    buildToolsVersion = "34.0.0"
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    signingConfigs {
        create("release") {
            val keyProps = java.util.Properties()
            val keyPropsFile = rootProject.file("key.properties")
            if (keyPropsFile.exists()) {
                keyProps.load(java.io.FileInputStream(keyPropsFile))
            }

            keyAlias = keyProps.getProperty("keyAlias")
            keyPassword = keyProps.getProperty("keyPassword")
            storeFile = keyProps.getProperty("storeFile")?.let { file(it) }
            storePassword = keyProps.getProperty("storePassword")
        }
    }

    defaultConfig {
        applicationId = "com.codewearlabs.pdfscanner"
        minSdk = flutter.minSdkVersion
        targetSdk = 35
        versionCode = flutter.versionCode
        versionName = flutter.versionName
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

flutter {
    source = "../.."
}
