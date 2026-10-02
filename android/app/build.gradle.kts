plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.dhafer.offline_study_assistant"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.dhafer.offline_study_assistant"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // flutter_gemma bundles native libraries for features this app doesn't
    // use (it runs text models on the CPU and keeps its own vector store):
    // ~125 MB per ABI. Checked on the phone: start, indexing and answering
    // still work without them.
    packaging {
        jniLibs {
            excludes += setOf(
                // Image models (MediaPipe vision, image generation).
                "**/libmediapipe_tasks_vision_jni.so",
                "**/libmediapipe_tasks_vision_image_generator_jni.so",
                "**/libimagegenerator_gpu.so",
                // Qualcomm NPU (QNN) runtime and dispatch.
                "**/libQnn*.so",
                "**/libLiteRtDispatch_Qualcomm.so",
                // WebGPU backend.
                "**/libLiteRtWebGpuAccelerator.so",
                "**/libLiteRtTopKWebGpuSampler.so",
                // qdrant edge vector store (flutter_gemma's RAG store).
                "**/libqdrant_edge_ffi.so",
            )
        }
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

flutter {
    source = "../.."
}
