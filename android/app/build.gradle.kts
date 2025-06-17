plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.headev.link_tattoo_manager"
    compileSdk = 35 
    ndkVersion = "29.0.13599879"

    defaultConfig {
        applicationId = "com.headev.link_tattoo_manager"
        minSdk = 21   
        targetSdk = 35
        versionCode = 1
        versionName = "1.0.0"
    }

    compileOptions {
        // Compatibilidad con Java 11+
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = "11"
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

dependencies {
    implementation("org.jetbrains.kotlin:kotlin-stdlib")
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    // Dependencias necesarias para Flutter
    implementation("androidx.core:core-ktx:1.12.0")
    implementation("androidx.appcompat:appcompat:1.6.1")
}
