pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            val localPropertiesFile = file("local.properties")
            if (localPropertiesFile.exists()) {
                localPropertiesFile.inputStream().use { properties.load(it) }
            }
            var sdkPath = properties.getProperty("flutter.sdk")
            val junctionDir = file("C:/flutter")
            if (junctionDir.exists() && (sdkPath == null || !file(sdkPath).exists() || !file("$sdkPath/packages/flutter_tools/gradle").exists())) {
                sdkPath = "C:/flutter"
                properties.setProperty("flutter.sdk", "C:\\flutter")
                localPropertiesFile.outputStream().use { properties.store(it, null) }
            }
            require(sdkPath != null && file(sdkPath).exists()) { "flutter.sdk not set in local.properties" }
            sdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.9.1" apply false
    id("org.jetbrains.kotlin.android") version "2.1.0" apply false
}

include(":app")
