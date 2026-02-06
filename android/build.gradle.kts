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
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

// 🧙‍♀️ HIMMY'S INSTANT FIX (Ambush Mode)
// Instead of waiting (which crashes), we inject the namespace instantly when the plugin loads.
subprojects {
    // This listens for the 'com.android.library' plugin (used by on_audio_query)
    pluginManager.withPlugin("com.android.library") {
        val android = extensions.findByName("android")
        if (android != null) {
            try {
                // We use reflection to set the namespace IMMEDIATELY.
                // If the library sets its own later, it overwrites ours (which is fine).
                // If it forgets (like on_audio_query), our default saves the day.
                val setNamespace = android.javaClass.getMethod("setNamespace", String::class.java)
                val safeName = "com.oxcy.fixed.${project.name.replace(Regex("[^a-zA-Z0-9_]"), "_")}"
                
                setNamespace.invoke(android, safeName)
                println("✅ Pre-injected namespace for: ${project.name}")
            } catch (e: Exception) {
                // Ignore errors to keep the build alive
            }
        }
    }
}
