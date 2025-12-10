allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

subprojects {
    project.evaluationDependsOn(":app")
    
    // Configure Kotlin JVM target for all Kotlin compilation tasks
    tasks.matching { it is org.jetbrains.kotlin.gradle.tasks.KotlinCompile }.configureEach {
        (this as org.jetbrains.kotlin.gradle.tasks.KotlinCompile).kotlinOptions {
            jvmTarget = "11"
        }
    }
    
    // Configure Java compilation tasks directly
    tasks.withType<JavaCompile>().configureEach {
        sourceCompatibility = "11"
        targetCompatibility = "11"
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
