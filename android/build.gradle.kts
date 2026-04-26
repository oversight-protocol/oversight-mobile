allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

// Force Java 17 + Kotlin JVM 17 across all Flutter plugin subprojects.
// Plugins like receive_sharing_intent compile their Kotlin at JVM target 17
// while older Flutter plugin templates leave Java at 1.8 — gradle then
// aborts with 'Inconsistent JVM-target compatibility'.
//
// jvmToolchain(17) on the kotlin extension drives BOTH the Kotlin and
// Java compile tasks to the same toolchain. plugins.withId hooks fire on
// plugin apply, before AGP finalizes anything.
subprojects {
    plugins.withId("org.jetbrains.kotlin.android") {
        extensions.getByType<org.jetbrains.kotlin.gradle.dsl.KotlinAndroidProjectExtension>()
            .jvmToolchain(17)
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
