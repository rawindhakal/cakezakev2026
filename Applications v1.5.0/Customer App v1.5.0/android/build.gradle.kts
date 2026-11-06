buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath("com.google.gms:google-services:4.4.2")
        classpath("com.google.firebase:firebase-crashlytics-gradle:3.0.3")
    }
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
// Fix legacy plugins that predate AGP 8 (e.g. flutter_paystack):
//  - inject a namespace when missing
//  - align Java/Kotlin JVM targets (plugin defaults to 1.8 while Kotlin picks the JDK's)
// Must register before evaluationDependsOn(":app") triggers subproject evaluation.
subprojects {
    afterEvaluate {
        val android = project.extensions.findByName("android")
        if (android != null) {
            val getNamespace = android.javaClass.methods.firstOrNull { it.name == "getNamespace" }
            if (getNamespace != null && getNamespace.invoke(android) == null) {
                android.javaClass.methods
                    .firstOrNull { it.name == "setNamespace" }
                    ?.invoke(android, project.group.toString())
            }

            // Old plugins (flutter_paystack: compileSdk 32) fail the AAR metadata check against
            // modern AndroidX; compile every plugin library against a current SDK.
            if (project.name != "app") {
                android.javaClass.methods
                    .firstOrNull { it.name == "compileSdkVersion" && it.parameterCount == 1 && it.parameterTypes[0] == Int::class.javaPrimitiveType }
                    ?.invoke(android, 36)
            }

            // AGP drives javac compatibility from android.compileOptions, not the JavaCompile task.
            val compileOptions = android.javaClass.methods
                .firstOrNull { it.name == "getCompileOptions" }?.invoke(android)
            if (compileOptions != null) {
                listOf("setSourceCompatibility", "setTargetCompatibility").forEach { setter ->
                    compileOptions.javaClass.methods
                        .firstOrNull { it.name == setter && it.parameterCount == 1 && it.parameterTypes[0].isAssignableFrom(JavaVersion::class.java) }
                        ?.invoke(compileOptions, JavaVersion.VERSION_17)
                }
            }
        }

        project.tasks
            .matching { it.name.startsWith("compile") && it.name.endsWith("Kotlin") }
            .configureEach {
                val kotlinOptions = this.javaClass.methods.firstOrNull { it.name == "getKotlinOptions" }?.invoke(this)
                kotlinOptions?.javaClass?.methods
                    ?.firstOrNull { it.name == "setJvmTarget" }
                    ?.invoke(kotlinOptions, "17")
            }
    }
}

// stripe_android's release lint needs com.google.android.gms:play-services-tapandpay,
// which isn't on public Maven, so lintVital fails dependency resolution and
// aborts the release build. Skip lint for plugin (library) subprojects only.
subprojects {
    if (project.name != "app") {
        tasks.configureEach {
            if (name.startsWith("lintVital") || name.startsWith("lintAnalyze") || name == "lintReport") {
                enabled = false
            }
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
