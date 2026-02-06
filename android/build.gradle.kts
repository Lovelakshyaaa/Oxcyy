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

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

// 🧙‍♀️ HIMMY'S NAMESPACE INJECTOR (The Magic Fix)
// This adds the missing "namespace" to old plugins automatically.
subprojects {
    afterEvaluate {
        // We look for the "android" extension on the plugin
        val android = extensions.findByName("android")
        if (android != null) {
            try {
                // Use Reflection to check if 'namespace' is missing
                // This bypasses strict compile-time checks
                val getNamespace = android.javaClass.getMethod("getNamespace")
                val currentNamespace = getNamespace.invoke(android) as String?

                if (currentNamespace == null) {
                    // Create a valid namespace from the project name
                    // e.g., "on_audio_query" -> "com.example.on_audio_query"
                    val safeName = project.name.replace("-", "_").replace(Regex("[^a-zA-Z0-9_]"), "")
                    val newNamespace = "com.example.fixed_namespace.$safeName"
                    
                    // Inject it!
                    val setNamespace = android.javaClass.getMethod("setNamespace", String::class.java)
                    setNamespace.invoke(android, newNamespace)
                    
                    println("💉 Auto-Fixed Namespace for project: ${project.name} -> $newNamespace")
                }
            } catch (e: Exception) {
                // If the plugin is weird, we ignore it to prevent crashing
                println("⚠️ Could not patch namespace for ${project.name}: $e")
            }
        }
    }
}
