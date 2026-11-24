#if defined(DM_PLATFORM_ANDROID)

#include "bridge.h"
#include <dmsdk/sdk.h>
#include <dmsdk/dlib/android.h>
#include <dmsdk/graphics/graphics_native.h>

namespace appmetrica {

static jobject bridge = 0;
static jmethodID submitMethod = 0;
static const char* const kBridgeClass = "com.defold.extension.qb.appmetrica.AppMetricaBridge";

/// Снимает исключение JNI и возвращает true, если вызов завершился ошибкой.
static bool ClearException(JNIEnv* env) {
    if (!env->ExceptionCheck()) {
        return false;
    }
    env->ExceptionClear();
    return true;
}

/// Принимает код ошибки и UTF-8-ответ Java в любом потоке SDK.
static void JNICALL OnComplete(JNIEnv* env, jclass, jlong id, jstring code, jbyteArray data) {
    std::string error;
    if (code) {
        const char* value = env->GetStringUTFChars(code, 0);
        if (!value) {
            ClearException(env);
            Complete(id, "sdk_error", "Не удалось прочитать код ошибки Android");
            return;
        }
        error = value;
        env->ReleaseStringUTFChars(code, value);
    }
    std::string payload;
    if (data) {
        payload.resize(env->GetArrayLength(data));
        if (!payload.empty()) {
            env->GetByteArrayRegion(data, 0, payload.size(), reinterpret_cast<jbyte*>(&payload[0]));
        }
    }
    if (ClearException(env)) {
        Complete(id, "sdk_error", "Не удалось прочитать ответ Android");
    } else {
        Complete(id, std::move(error), std::move(payload));
    }
}

/// Загружает Java-адаптер и связывает три JNI-точки входа.
bool InitializePlatform() {
    dmAndroid::ThreadAttacher thread;
    JNIEnv* env = thread.GetEnv();
    if (!env) {
        return false;
    }
    jobject activity = dmGraphics::GetNativeAndroidActivity();
    if (!activity) {
        return false;
    }
    jclass type = dmAndroid::LoadClass(env, activity, kBridgeClass);
    if (ClearException(env) || !type) {
        dmLogError("AppMetrica: failed to load Android bridge");
        return false;
    }

    JNINativeMethod nativeMethod = {
        const_cast<char*>("complete"), const_cast<char*>("(JLjava/lang/String;[B)V"),
        reinterpret_cast<void*>(OnComplete)
    };
    jmethodID constructor = env->GetMethodID(type, "<init>", "(Landroid/app/Activity;)V");
    if (!ClearException(env) && constructor) {
        submitMethod = env->GetMethodID(type, "submit", "(JLjava/lang/String;[B)Z");
        if (!ClearException(env) && submitMethod && env->RegisterNatives(type, &nativeMethod, 1) == JNI_OK) {
            jobject local = env->NewObject(type, constructor, activity);
            if (!ClearException(env) && local) {
                bridge = env->NewGlobalRef(local);
                env->DeleteLocalRef(local);
            }
        }
    }
    env->DeleteLocalRef(type);
    if (ClearException(env) || !bridge) {
        dmLogError("AppMetrica: failed to initialize Android bridge");
        return false;
    }
    return true;
}

/// Передаёт байты JSON Java-очереди, сохраняя UTF-8 без преобразования через JNI Modified UTF-8.
bool Submit(uint64_t id, const char* operation, const char* json, size_t size) {
    dmAndroid::ThreadAttacher thread;
    JNIEnv* env = thread.GetEnv();
    if (!env || !bridge) {
        return false;
    }
    jstring name = env->NewStringUTF(operation);
    if (ClearException(env) || !name) {
        return false;
    }
    jbyteArray bytes = env->NewByteArray(size);
    bool accepted = false;
    if (!ClearException(env) && bytes) {
        env->SetByteArrayRegion(bytes, 0, size, reinterpret_cast<const jbyte*>(json));
        if (!ClearException(env)) {
            accepted = env->CallBooleanMethod(bridge, submitMethod, static_cast<jlong>(id), name, bytes);
            if (ClearException(env)) {
                accepted = false;
            }
        }
        env->DeleteLocalRef(bytes);
    }
    env->DeleteLocalRef(name);
    return accepted;
}

/// Отпускает JNI-ссылку. Фоновые ответы отсеиваются по id.
void FinalizePlatform() {
    dmAndroid::ThreadAttacher thread;
    if (thread.GetEnv() && bridge) {
        thread.GetEnv()->DeleteGlobalRef(bridge);
    }
    bridge = 0;
    submitMethod = 0;
}

}

#endif
