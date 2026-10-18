/* Disposable original-engine reproduction only. Never shipped. */
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <objbase.h>
#include <wchar.h>
/* Same documented activation as the policy canary: Template_COM denies it, but
   the request itself makes the original boxed RpcSs/DcomLaunch start. */
static const CLSID BitsManager = { 0x4991d34b, 0x80a1, 0x4291, { 0x83, 0xb6, 0x33, 0x28, 0x36, 0x6b, 0x90, 0x97 } };
static const IID Unknown = { 0x00000000, 0x0000, 0x0000, { 0xc0, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x46 } };
static void activate_com(void) {
    IUnknown *object = NULL;
    HRESULT initialized = CoInitializeEx(NULL, COINIT_MULTITHREADED);
    if (FAILED(initialized)) return;
    if (SUCCEEDED(CoCreateInstance(&BitsManager, NULL, CLSCTX_LOCAL_SERVER, &Unknown, (void **)&object)) && object)
        object->lpVtbl->Release(object);
    CoUninitialize();
}
int wmain(int argc, wchar_t **argv) {
    wchar_t image[32768], command[32768];
    STARTUPINFOW startup = { sizeof(startup) };
    PROCESS_INFORMATION child = { 0 };
    DWORD code = 0;
    if (!GetModuleHandleW(L"SbieDll.dll")) return 71;
    if (argc == 2 && wcscmp(argv[1], L"crash") == 0) {
        RaiseException(0xe0424242UL, EXCEPTION_NONCONTINUABLE, 0, NULL);
        return 72;
    }
    if (argc == 2 && wcscmp(argv[1], L"child") == 0) {
        activate_com();
        return 0;
    }
    if (argc != 1 || !GetModuleFileNameW(NULL, image, 32768)) return 73;
    if (swprintf_s(command, 32768, L"\"%ls\" child", image) < 0) return 74;
    /* Like the policy canary, create the boxed child while the original
       helpers may still be starting, then use COM from both processes. */
    if (!CreateProcessW(image, command, NULL, NULL, FALSE, CREATE_NO_WINDOW,
                        NULL, NULL, &startup, &child)) return 75;
    CloseHandle(child.hThread);
    activate_com();
    if (WaitForSingleObject(child.hProcess, 30000) != WAIT_OBJECT_0 ||
        !GetExitCodeProcess(child.hProcess, &code)) {
        CloseHandle(child.hProcess);
        return 76;
    }
    CloseHandle(child.hProcess);
    return code == 0 ? 0 : 77;
}
