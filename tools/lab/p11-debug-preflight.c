/* Synthetic native debugger preflight only; never shipped or engine proof. */
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
int wmain(int argc, wchar_t **argv) {
    unsigned int attempt;
    if (argc != 2) return 71;
    for (attempt = 0; attempt < 300; ++attempt) {
        if (GetFileAttributesW(argv[1]) != INVALID_FILE_ATTRIBUTES) {
            RaiseException(0xe0424242UL, EXCEPTION_NONCONTINUABLE, 0, NULL);
            return 73;
        }
        Sleep(100);
    }
    return 72; /* No debugger confirmed: exit naturally without a crash. */
}
