import java.io.File

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
}

android {
    namespace = "com.hiair"
    compileSdk = 34

    defaultConfig {
        applicationId = "com.hiair"
        minSdk = 26
        targetSdk = 34
        versionCode = 1
        versionName = "0.1.0"
    }

    buildTypes {
        debug {
            buildConfigField("String", "API_BASE_URL", "\"http://10.0.2.2:8000\"")
            buildConfigField("String", "SUPABASE_URL", "\"https://qhxesaemlhzwbunpqjoo.supabase.co\"")
            buildConfigField("String", "SUPABASE_ANON_KEY", "\"eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFoeGVzYWVtbGh6d2J1bnBxam9vIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzk3Nzk5MzgsImV4cCI6MjA5NTM1NTkzOH0.B9TOtpcqQZS81Sx5vlRyN3nhxZTWQWzaqZ-F8RFbCZw\"")
            buildConfigField("String", "SUPABASE_REDIRECT_URI", "\"hiair://auth/callback\"")
            manifestPlaceholders["usesCleartextTraffic"] = "true"
        }
        release {
            isMinifyEnabled = false
            buildConfigField("String", "API_BASE_URL", "\"https://api.hiair.app\"")
            buildConfigField("String", "SUPABASE_URL", "\"https://qhxesaemlhzwbunpqjoo.supabase.co\"")
            buildConfigField("String", "SUPABASE_ANON_KEY", "\"eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFoeGVzYWVtbGh6d2J1bnBxam9vIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzk3Nzk5MzgsImV4cCI6MjA5NTM1NTkzOH0.B9TOtpcqQZS81Sx5vlRyN3nhxZTWQWzaqZ-F8RFbCZw\"")
            buildConfigField("String", "SUPABASE_REDIRECT_URI", "\"hiair://auth/callback\"")
            manifestPlaceholders["usesCleartextTraffic"] = "false"
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions {
        jvmTarget = "17"
    }
    buildFeatures {
        buildConfig = true
    }
}

tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
    exclude("**/MainActivity.kt")
}

val legacyMainActivityPath = "src/main/java/com/hiair/MainActivity.kt"

tasks.register("sanitizeLegacyMainActivity") {
    group = "verification"
    description = "Sanitize duplicated legacy MainActivity and write report"

    doLast {
        val legacyFile = project.file(legacyMainActivityPath)
        val reportDir = project.layout.buildDirectory.dir("reports").get().asFile
        reportDir.mkdirs()
        val reportFile = File(reportDir, "mainactivity-sanity.txt")

        if (!legacyFile.exists()) {
            reportFile.writeText("status=missing\nfile=$legacyMainActivityPath\n")
            return@doLast
        }

        val raw = legacyFile.readText()
        val packageCount = Regex("(?m)^package\\s+com\\.hiair\\s*$").findAll(raw).count()
        val lineCount = raw.lineSequence().count()

        if (packageCount > 1) {
            legacyFile.writeText(
                """
                package com.hiair

                // Auto-sanitized legacy file.
                // Actual Android entrypoint is AppMainActivity.
                class MainActivitySanitizedMarker
                """.trimIndent() + "\n"
            )
            reportFile.writeText(
                """
                status=sanitized
                file=$legacyMainActivityPath
                previous_package_count=$packageCount
                previous_line_count=$lineCount
                """.trimIndent() + "\n"
            )
            println("Sanitized duplicated legacy MainActivity.kt ($packageCount package headers, $lineCount lines).")
        } else {
            reportFile.writeText(
                """
                status=ok
                file=$legacyMainActivityPath
                package_count=$packageCount
                line_count=$lineCount
                """.trimIndent() + "\n"
            )
        }
    }
}

tasks.named("preBuild").configure {
    dependsOn("sanitizeLegacyMainActivity")
}

dependencies {
    implementation("androidx.core:core-ktx:1.13.1")
    implementation("androidx.appcompat:appcompat:1.7.1")
    implementation("androidx.security:security-crypto:1.1.0-alpha06")
    implementation("androidx.browser:browser:1.8.0")
    implementation("com.google.android.material:material:1.13.0")
    testImplementation("junit:junit:4.13.2")
    testImplementation("org.mockito:mockito-core:5.12.0")
}
