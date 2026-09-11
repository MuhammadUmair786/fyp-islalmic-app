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
    subprojects {
        afterEvaluate {
            val androidExtension = extensions.findByName("android")
            if (androidExtension != null) {
                val namespaceMethod = androidExtension.javaClass.getMethod("getNamespace")
                val namespace = namespaceMethod.invoke(androidExtension)
                if (namespace == null) {
                    val setNamespaceMethod = androidExtension.javaClass.getMethod("setNamespace", String::class.java)
                    // Yeh automatically error waale package ka naam namespace bana dega
                    setNamespaceMethod.invoke(androidExtension, "com.example.${project.name}")
                }
            }
        }
    }
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
