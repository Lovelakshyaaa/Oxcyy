import org.jetbrains.kotlin.gradle.tasks.KotlinCompile

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

// -----------------------------------------------------------
// 🧙‍♀️ HIMMY'S FINAL FIXER (Crash-Proof Edition)
// -----------------------------------------------------------
subprojects {
    // 1. NAMESPACE AMBUSH (This part was working perfectly!)
    // It listens for the Android plugin and injects the ID instantly.
    pluginManager.withPlugin("com.android.library") {
        val android = extensions.findByName("android")
        if (android != null) {
            try {
                val setNamespace = android.javaClass.getMethod("setNamespace", String::class.java)
                val safeName = "com.oxcy.fixed.${project.name.replace(Regex("[^a-zA-Z0-9_]"), "_")}"
                setNamespace.invoke(android, safeName)
                println("✅ Pre-injected namespace for: ${project.name}")
            } catch (e: Exception) {
                // Ignore harmless errors
            }
        }
    }

    // 2. JAVA 17 ENFORCER (Lazy Mode - No 'afterEvaluate')
    // We use 'configureEach' which waits for tasks safely without crashing.
    
    // Force Java Compilation to Version 17
    tasks.withType<JavaCompile>().configureEach {
        sourceCompatibility = "17"
        targetCompatibility = "17"
    }

    // Force Kotlin Compilation to Version 17
    tasks.withType<KotlinCompile>().configureEach {
        kotlinOptions {
            jvmTarget = "17"
        }
    }
}
