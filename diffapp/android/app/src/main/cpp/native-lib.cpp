#include <jni.h>

extern "C" JNIEXPORT jint JNICALL
Java_dummy_Dummy_unreferenced(JNIEnv*, jobject) {
  return 42;
}
