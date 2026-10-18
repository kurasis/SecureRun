/* P02 disposable lab inspector. Original interface declarations, no upstream code. */
#define WIN32_LEAN_AND_MEAN
#define _WIN32_WINNT 0x0A00
#include <windows.h>
#include <stdio.h>
#include <wchar.h>

typedef LONG (*get_version_fn)(WCHAR *, ULONG *);
typedef LONG (*query_process_fn)(HANDLE, ULONG, WCHAR *, WCHAR *, WCHAR *, ULONG *, ULONG64 *);
typedef LONG (*driver_info_fn)(ULONG, VOID *, ULONG);

int wmain(int argc, wchar_t **argv) {
    WCHAR dll[MAX_PATH], version[16] = {0}, box[40] = {0};
    ULONG abi = 0, flags = 0, session = 0;
    LONG health, context, info;
    BOOL matches;
    HMODULE module;
    get_version_fn get_version;
    query_process_fn query_process;
    driver_info_fn driver_info;
    if (argc != 2 || wcslen(argv[1]) > MAX_PATH - 20) return 64;
    if (swprintf_s(dll, MAX_PATH, L"%s\\SbieDll.dll", argv[1]) < 0) return 64;
    if (!SetDefaultDllDirectories(LOAD_LIBRARY_SEARCH_SYSTEM32 | LOAD_LIBRARY_SEARCH_USER_DIRS)) return 65;
    module = LoadLibraryExW(dll, NULL, LOAD_LIBRARY_SEARCH_DLL_LOAD_DIR | LOAD_LIBRARY_SEARCH_SYSTEM32);
    if (!module) {
        printf("{\"stage\":\"dll_load\",\"win32_error\":%lu,\"result\":\"BLOCKED\"}\n", GetLastError());
        return 2;
    }
    /* Windows FARPROC conversion is the supported GetProcAddress convention. */
    get_version = (get_version_fn)(void *)GetProcAddress(module, "SbieApi_GetVersionEx");
    query_process = (query_process_fn)(void *)GetProcAddress(module, "SbieApi_QueryProcessEx2");
    driver_info = (driver_info_fn)(void *)GetProcAddress(module, "SbieApi_QueryDrvInfo");
    if (!get_version || !query_process || !driver_info) return 3;
    health = get_version(version, &abi);
    context = query_process((HANDLE)(ULONG_PTR)GetCurrentProcessId(), 0, box, NULL, NULL, &session, NULL);
    info = driver_info(0, &flags, sizeof(flags));
    matches = wcscmp(version, L"5.73.8") == 0 && abi == 0x57230UL;
    printf("{\"stage\":\"driver_query\",\"version_status\":\"%08lx\",\"abi\":%lu,"
           "\"context_status\":\"%08lx\",\"driver_info_status\":\"%08lx\","
           "\"driver_flags\":%lu,\"context\":\"%s\",\"version_matches_pin\":%s,\"result\":\"%s\"}\n",
           (ULONG)health, abi, (ULONG)context, (ULONG)info, flags,
           context == 0 ? "BOXED" : ((ULONG)context == 0xc000000bUL && health == 0 ? "UNBOXED" : "UNKNOWN"),
           matches ? "true" : "false",
           health == 0 && (ULONG)context == 0xc000000bUL && info == 0 && matches ? "PASS" : "BLOCKED");
    FreeLibrary(module);
    return health == 0 && (ULONG)context == 0xc000000bUL && info == 0 && matches ? 0 : 2;
}
