/* P01 lab-only executable. No Sandboxie API, file writes or target launching. */
#ifndef _WIN32
#error This probe requires Windows; a Linux build cannot validate the lab.
#endif
#if !defined(_M_X64) && !defined(__x86_64__)
#error Build this probe for x64; report native ARM64 only as the emulation host.
#endif
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <stdio.h>

int main(void) {
    SYSTEM_INFO info;
    GetNativeSystemInfo(&info);
    if ((info.wProcessorArchitecture != PROCESSOR_ARCHITECTURE_AMD64 &&
         info.wProcessorArchitecture != PROCESSOR_ARCHITECTURE_ARM64) ||
        sizeof(void *) != 8) {
        fputs("A 64-bit Windows process on x64 or ARM64 is required.\n", stderr);
        return 2;
    }
    printf("{\"schema_version\":1,\"platform\":\"Windows\","
           "\"architecture\":\"x64\",\"pointer_bits\":64,"
           "\"native_architecture\":\"%s\","
           "\"pid\":%lu,\"result\":\"PASS\"}\n",
           info.wProcessorArchitecture == PROCESSOR_ARCHITECTURE_ARM64 ? "arm64" : "x64",
           (unsigned long)GetCurrentProcessId());
    return 0;
}
