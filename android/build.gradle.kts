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

// Some plugins (e.g. flutter_native_splash) pin an old compileSdk in their own
// build.gradle, which fails the AAR metadata check against newer AndroidX
// dependencies. Raise any subproject that sits below the app's compileSdk.
// Must run before the evaluationDependsOn(":app") block below, which forces
// :app to be evaluated early.
val minimumCompileSdk = 36

subprojects {
    afterEvaluate {
        val androidExtension = extensions.findByName("android") ?: return@afterEvaluate
        androidExtension.withGroovyBuilder {
            val currentCompileSdk =
                ("getCompileSdkVersion"() as? String)
                    ?.substringAfter("android-")
                    ?.toIntOrNull()
            if (currentCompileSdk != null && currentCompileSdk < minimumCompileSdk) {
                "compileSdkVersion"(minimumCompileSdk)
            }
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
