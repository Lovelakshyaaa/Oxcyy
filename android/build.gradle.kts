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
// 🧙‍♀️ HIMMY'S COMBINED FIXER (Namespace + Java 17)
// -----------------------------------------------------------
subprojects {
    // 1. AMBUSH: Inject Namespace when plugin loads (Fixes AGP 8.0 error)
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

    // 2. ENFORCER: Force everyone to use Java 17 (Fixes JVM Mismatch)
    // This overrides the "1.8" setting in old plugins
    afterEvaluate {
        tasks.withType<JavaCompile> {
            sourceCompatibility = "17"
            targetCompatibility = "17"
        }
        
        // Force Kotlin to match Java 17
        tasks.withType<KotlinCompile>().configureEach {
            kotlinOptions {
                jvmTarget = "17"
            }
        }
    }
}
