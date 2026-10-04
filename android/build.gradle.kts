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

/*
 * tflite_flutter uses Java 11 while the current Kotlin compiler
 * targets JVM 21. Make both targets consistent for this plugin.
 */
subprojects {
    if (name == "tflite_flutter") {
        tasks.withType<JavaCompile>().configureEach {
            sourceCompatibility = "21"
            targetCompatibility = "21"
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}