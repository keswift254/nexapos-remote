allprojects {
    repositories {
        // Local mirror of io.flutter engine artifacts that couldn't be
        // downloaded due to a network TLS corruption bug affecting large
        // files on this machine. See C:\Users\felix\local-maven-repo.
        maven {
            name = "localFlutterEngineRepo"
            url = uri("file:///C:/Users/felix/local-maven-repo")
        }
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

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
