plugins {
    id("org.gradle.toolchains.foojay-resolver-convention") version "0.8.0"
}
rootProject.name = "test"

include(":plugin-tests-support")
project(":plugin-tests-support").projectDir = File(settingsDir, "../../plugin-tests-support")
