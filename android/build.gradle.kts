allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val tempBuildDir = java.io.File(System.getProperty("java.io.tmpdir"), "smartopd_build")
val newBuildDir: Directory = objects.directoryProperty().fileValue(tempBuildDir).get()

rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = objects.directoryProperty()
        .fileValue(java.io.File(tempBuildDir, project.name))
        .get()
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

subprojects {
    project.evaluationDependsOn(":app")
}

// Copy APK to root build directory for Flutter CLI
val copyApkTask = tasks.register("copyApkToFlutterBuildDir") {
    doLast {
        val srcApk = java.io.File(tempBuildDir, "app/outputs/flutter-apk/app-debug.apk")
        val destDir = java.io.File(rootProject.projectDir, "../build/app/outputs/flutter-apk")
        if (srcApk.exists()) {
            destDir.mkdirs()
            srcApk.copyTo(java.io.File(destDir, "app-debug.apk"), overwrite = true)
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
