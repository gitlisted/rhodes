#pragma once

#include "rhodes/JNIRhodes.h"

namespace rhoelements {

class MethodResultJni;

class MethodExecutorJni
{
    static const char * const METHOD_EXECUTOR_CLASS;

    static jclass s_MethodExecutorClass;
    static jmethodID s_midRun;
    static jmethodID s_midRunWithSeparateThread;
    static jmethodID s_midRunWithUiThread;

    static void run(jhobject jhTask);
    static void runWithSeparateThread(jhobject jhTask);
    static void runWithUiThread(jhobject jhTask);

    bool m_separateThread;
    bool m_uiThread;

protected:
    static JNIEnv* jniInit();

public:
    MethodExecutorJni(bool separateThread, bool uiThread) : m_separateThread(separateThread), m_uiThread(uiThread) {}

    void run(jhobject jhTask, MethodResultJni& result);

    bool shouldRunWithThread() { return m_separateThread; }
    bool shouldRunWithUiThread() { return m_uiThread; }
    virtual ~MethodExecutorJni() {}
};

}
