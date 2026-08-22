import com.android.build.gradle.LibraryExtension
import com.android.build.gradle.AppExtension

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

    plugins.withId("com.android.library") {
        extensions.configure<LibraryExtension> {
            compileSdk = 36
        }
    }

    plugins.withId("com.android.application") {
        extensions.configure<AppExtension> {
            compileSdkVersion(36)
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
