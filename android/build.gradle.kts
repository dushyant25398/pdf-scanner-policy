plugins {
    id("com.android.application") version "8.9.1" apply false
    id("org.jetbrains.kotlin.android") version "2.1.0" apply false
    id("com.google.gms.google-services") version "4.4.4" apply false
}

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

subprojects {
    project.plugins.configureEach {
        val pluginName = this::class.java.name
        val isAndroid = pluginName.contains("com.android.build.gradle.api.AndroidBasePlugin") ||
                        pluginName.contains("com.android.build.gradle.AppPlugin") ||
                        pluginName.contains("com.android.build.gradle.LibraryPlugin")
        
        if (isAndroid) {
            val android = project.extensions.findByName("android")
            if (android != null) {
                try {
                    val getNamespace = android::class.java.getMethod("getNamespace")
                    val setNamespace = android::class.java.getMethod("setNamespace", String::class.java)
                    
                    val targetNamespace = if (project.name == "edge_detection") "com.sample.edgedetection" 
                                         else "com.example.${project.name.replace("-", "_")}"
                    
                    if (getNamespace.invoke(android) == null) {
                        setNamespace.invoke(android, targetNamespace)
                    }
                } catch (e: Throwable) { }
            }
        }
        
        if (pluginName.contains("org.jetbrains.kotlin.gradle.plugin")) {
            project.tasks.withType(org.jetbrains.kotlin.gradle.tasks.KotlinCompile::class.java).configureEach {
                kotlinOptions {
                    jvmTarget = "1.8"
                }
            }
        }
    }

    val applyCompatibility = { p: org.gradle.api.Project ->
        val android = p.extensions.findByName("android")
        if (android != null) {
            try {
                val compileOptions = android.javaClass.getMethod("getCompileOptions").invoke(android)
                val javaVersion8 = org.gradle.api.JavaVersion.VERSION_1_8
                
                try {
                    val mSource = compileOptions.javaClass.getMethod("setSourceCompatibility", javaVersion8.javaClass)
                    mSource.invoke(compileOptions, javaVersion8)
                } catch (e: Exception) {}
                try {
                    val mTarget = compileOptions.javaClass.getMethod("setTargetCompatibility", javaVersion8.javaClass)
                    mTarget.invoke(compileOptions, javaVersion8)
                } catch (e: Exception) {}
            } catch (e: Exception) {}
        }
    }

    if (project.state.executed) {
        applyCompatibility(project)
    } else {
        project.afterEvaluate {
            applyCompatibility(this)
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
