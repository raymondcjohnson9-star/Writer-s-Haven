plugins {
id("com.android.application")
id("org.jetbrains.kotlin.android")
}

android {
namespace = "com.writershaven.app"
compileSdk = 35

defaultConfig {
    applicationId = "com.writershaven.app"
    minSdk = 23
    targetSdk = 35
    versionCode = 1
    versionName = "1.0"
}

buildFeatures {
    compose = true
}

composeOptions {
    kotlinCompilerExtensionVersion = "2.0.21"
}

compileOptions {
    sourceCompatibility = JavaVersion.VERSION_17
    targetCompatibility = JavaVersion.VERSION_17
}

kotlinOptions {
    jvmTarget = "17"
}

}

dependencies {
val composeBom = platform("androidx.compose:compose-bom:2024.12.01")

implementation(composeBom)
androidTestImplementation(composeBom)

implementation("androidx.activity:activity-compose:1.9.3")
implementation("androidx.compose.ui:ui")
implementation("androidx.compose.ui:ui-tooling-preview")
implementation("androidx.compose.material3:material3")
implementation("androidx.compose.material:material-icons-extended")

debugImplementation("androidx.compose.ui:ui-tooling")

}
