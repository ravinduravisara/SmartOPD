allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Flutter's CLI installs the APK from <project>/build, so Gradle must build
// there. Moving it elsewhere makes `flutter run` install a stale APK.
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

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
