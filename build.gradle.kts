plugins {
    alias(libs.plugins.kotlin.jvm)
    alias(libs.plugins.shadow)
    application
}

group = "com.helltar"
version = "1.0.0"

repositories {
    mavenCentral()
}

dependencies {
    implementation(libs.tgbots.module) { exclude("org.telegram", "telegrambots-webhook") }
    implementation(libs.heartbeat)

    implementation(libs.twitch4j)
    implementation(libs.dotenv.kotlin)

    runtimeOnly(libs.sqlite.jdbc)
    implementation(libs.exposed.core)
    implementation(libs.exposed.jdbc)
    implementation(libs.exposed.java.time)

    implementation(libs.kotlin.logging)
    runtimeOnly(libs.logback.classic)
}

application {
    mainClass.set("com.helltar.twitchviewerbot.MainKt")
}

kotlin {
    jvmToolchain(21)
}
