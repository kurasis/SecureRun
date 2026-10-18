/* Disposable original-engine reproduction only. Never shipped. */
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <wchar.h>
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
    if (argc == 2 && wcscmp(argv[1], L"child") == 0) return 0;
    if (argc != 1 || !GetModuleFileNameW(NULL, image, 32768)) return 73;
    if (swprintf_s(command, 32768, L"\"%ls\" child", image) < 0) return 74;
    if (!CreateProcessW(image, command, NULL, NULL, FALSE, CREATE_NO_WINDOW,
                        NULL, NULL, &startup, &child)) return 75;
    CloseHandle(child.hThread);
    if (WaitForSingleObject(child.hProcess, 30000) != WAIT_OBJECT_0 ||
        !GetExitCodeProcess(child.hProcess, &code)) {
        CloseHandle(child.hProcess);
        return 76;
    }
    CloseHandle(child.hProcess);
    return code == 0 ? 0 : 77;
}
