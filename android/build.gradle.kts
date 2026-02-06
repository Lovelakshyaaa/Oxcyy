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
// 🧙‍♀️ THE FINAL FIX (User's Logic + Himmy's Payload)
// -----------------------------------------------------------
subprojects {

    // 1. NAMESPACE FIX (Safe Listener)
    // This runs instantly if the plugin is already there, or waits if it's not.
    pluginManager.withPlugin("com.android.library") {
        val android = extensions.findByName("android")
        if (android != null) {
            try {
                val setNamespace = android.javaClass.getMethod("setNamespace", String::class.java)
                val safeName = "com.oxcy.fixed.${project.name.replace(Regex("[^a-zA-Z0-9_]"), "_")}"
                setNamespace.invoke(android, safeName)
                println("✅ Namespace injected for: ${project.name}")
            } catch (e: Exception) {
                // Ignore
            }
        }
    }

    // 2. JAVA 17 FIX (Using YOUR State Check Logic) 🧠
    val applyJavaFix = { p: Project ->
        // A. Force Android Plugin internal settings to Java 17
        val android = p.extensions.findByName("android")
        if (android != null) {
            try {
                val getCompileOptions = android.javaClass.getMethod("getCompileOptions")
                val compileOptions = getCompileOptions.invoke(android)
                
                val setSource = compileOptions.javaClass.getMethod("setSourceCompatibility", JavaVersion::class.java)
                val setTarget = compileOptions.javaClass.getMethod("setTargetCompatibility", JavaVersion::class.java)
                
                setSource.invoke(compileOptions, JavaVersion.VERSION_17)
                setTarget.invoke(compileOptions, JavaVersion.VERSION_17)
                println("☕ Java 17 enforced on Android settings for: ${p.name}")
            } catch (e: Exception) {}
        }

        // B. Force Tasks
        p.tasks.withType<JavaCompile>().configureEach {
            sourceCompatibility = "17"
            targetCompatibility = "17"
        }
        p.tasks.withType<KotlinCompile>().configureEach {
            kotlinOptions {
                jvmTarget = "17"
            }
        }
    }

    // THE LOGIC YOU PROVIDED 👇
    if (project.state.executed) {
        // Project is already done, so we apply immediately!
        println("⚡ Project ${project.name} already evaluated. Applying fix NOW.")
        applyJavaFix(project)
    } else {
        // Project is loading, so we wait.
        project.afterEvaluate {
            println("⏳ Project ${project.name} finished loading. Applying fix.")
            applyJavaFix(this)
        }
    }
}
