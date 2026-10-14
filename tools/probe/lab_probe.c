/* P01 lab-only executable. No Sandboxie API, file writes or target launching. */
#ifndef _WIN32
#error This probe requires Windows; a Linux build cannot validate the lab.
#endif
#if !defined(_M_X64) && !defined(__x86_64__)
#error Build this probe for x64; report native ARM64 only as the emulation host.
#endif
#define WIN32_LEAN_AND_MEAN
#define _WIN32_WINNT 0x0A00
#include <windows.h>
#include <stdio.h>

int main(void) {
    USHORT process_machine = 0;
    USHORT native_machine = 0;
    /* GetNativeSystemInfo can report an emulated view; use the explicit machine API. */
    if (!IsWow64Process2(GetCurrentProcess(), &process_machine, &native_machine)) {
        fprintf(stderr, "Machine observation failed: %lu\n", (unsigned long)GetLastError());
        return 3;
    }
    if ((native_machine != IMAGE_FILE_MACHINE_AMD64 &&
         native_machine != IMAGE_FILE_MACHINE_ARM64) ||
        sizeof(void *) != 8) {
        fputs("A 64-bit Windows process on x64 or ARM64 is required.\n", stderr);
        return 2;
    }
    printf("{\"schema_version\":1,\"platform\":\"Windows\","
           "\"architecture\":\"x64\",\"pointer_bits\":64,"
           "\"native_architecture\":\"%s\","
           "\"pid\":%lu,\"result\":\"PASS\"}\n",
           native_machine == IMAGE_FILE_MACHINE_ARM64 ? "arm64" : "x64",
           (unsigned long)GetCurrentProcessId());
    return 0;
}
