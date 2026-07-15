repositories {
    mavenCentral()
}

plugins {
    kotlin("jvm") version "2.0.20"
    kotlin("plugin.serialization") version "2.0.20"
}

group = "com.yandex"
version = "1.0-SNAPSHOT"

dependencies {
    testImplementation(project(":plugin-tests-support"))
}

tasks.test {
    useTestNG {
        suiteXmlFiles = listOf(File("src/test/resources/testng.xml"))
    }
}

kotlin {
    jvmToolchain(20)
}
