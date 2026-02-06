import org.jetbrains.kotlin.gradle.tasks.KotlinCompile
import org.gradle.api.JavaVersion

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
// 🧙‍♀️ HIMMY'S GOD-MODE FIXER
// -----------------------------------------------------------
subprojects {
    // 1. NAMESPACE AMBUSH (Keep this, it is working!)
    pluginManager.withPlugin("com.android.library") {
        val android = extensions.findByName("android")
        if (android != null) {
            try {
                val setNamespace = android.javaClass.getMethod("setNamespace", String::class.java)
                val safeName = "com.oxcy.fixed.${project.name.replace(Regex("[^a-zA-Z0-9_]"), "_")}"
                setNamespace.invoke(android, safeName)
                println("✅ Pre-injected namespace for: ${project.name}")
            } catch (e: Exception) {
                // Ignore
            }
        }
    }

    // 2. JAVA 17 OVERRIDE (The Fix for 'Inconsistent JVM-target')
    // We use afterEvaluate at the TOP LEVEL (Safe) to overwrite the plugin's 1.8 setting.
    afterEvaluate {
        // A. Force the Android Plugin's internal settings to Java 17
        val android = extensions.findByName("android")
        if (android != null) {
            try {
                // Access 'compileOptions' via reflection to avoid import errors
                val getCompileOptions = android.javaClass.getMethod("getCompileOptions")
                val compileOptions = getCompileOptions.invoke(android)
                
                // Force Source and Target to Java 17
                val setSource = compileOptions.javaClass.getMethod("setSourceCompatibility", JavaVersion::class.java)
                val setTarget = compileOptions.javaClass.getMethod("setTargetCompatibility", JavaVersion::class.java)
                
                setSource.invoke(compileOptions, JavaVersion.VERSION_17)
                setTarget.invoke(compileOptions, JavaVersion.VERSION_17)
                println("☕ Forced Java 17 for: ${project.name}")
            } catch (e: Exception) {
                // If this fails, the task loop below is our backup
            }
        }

        // B. Force all Java Compilation Tasks to 17
        tasks.withType<JavaCompile>().configureEach {
            sourceCompatibility = "17"
            targetCompatibility = "17"
        }

        // C. Force all Kotlin Compilation Tasks to 17
        tasks.withType<KotlinCompile>().configureEach {
            kotlinOptions {
                jvmTarget = "17"
            }
        }
    }
}
