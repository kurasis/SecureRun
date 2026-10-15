/* Fixed benign disposable compatibility fixture. Never a product helper. */
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <shlobj.h>
#include <wchar.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#pragma comment(lib,"shell32.lib")
#pragma comment(lib,"ole32.lib")
#pragma comment(lib,"uuid.lib")
typedef LONG (WINAPI *query_fn)(HANDLE,WCHAR*,WCHAR*,WCHAR*,ULONG*);
static BOOL member(void) {
 HMODULE module=GetModuleHandleW(L"SbieDll.dll");if(!module)return FALSE;
 query_fn query=(query_fn)(void*)GetProcAddress(module,"SbieApi_QueryProcess");WCHAR box[40]={0};
 return query&&query((HANDLE)(ULONG_PTR)GetCurrentProcessId(),box,NULL,NULL,NULL)==0&&box[0];
}
int wmain(int argc,wchar_t **argv) {
 if(argc==3&&wcscmp(argv[1],L"secret-probe")==0){
  if(!member())return 91;
  PWSTR base=NULL;WCHAR path[2048];DWORD count=0;
  if(SHGetKnownFolderPath(&FOLDERID_LocalAppData,0,NULL,&base)!=S_OK)return 65;
  int size=swprintf_s(path,2048,L"%ls\\SecureRunP09Protocol\\secret-result.json",base);CoTaskMemFree(base);if(size<=0)return 65;
  HANDLE marker=CreateFileW(path,GENERIC_WRITE,0,NULL,CREATE_NEW,FILE_ATTRIBUTE_NORMAL|FILE_FLAG_OPEN_REPARSE_POINT,NULL);if(marker==INVALID_HANDLE_VALUE)return 66;
  WCHAR value[128];BOOL clean=GetEnvironmentVariableW(L"SECURERUN_P09_SECRET",value,128)==0;
  const char *json=clean&&wcscmp(argv[2],L"P09_ARGV_SECRET_CANARY")==0?"{\"boxed\":true,\"argv_secret_received\":true,\"inherited_environment_secret_absent\":true}":"{\"boxed\":true,\"argv_secret_received\":false,\"inherited_environment_secret_absent\":false}";
  if(!WriteFile(marker,json,(DWORD)strlen(json),&count,NULL)){CloseHandle(marker);return 67;}FlushFileBuffers(marker);CloseHandle(marker);
  /* Synthetic input only. The manager must not capture this as its own log. */
  fwprintf(stderr,L"%ls\nFORGED_EVENT\n",argv[2]);fflush(stderr);
  fwprintf(stdout,L"%ls\n",argv[2]);fflush(stdout);Sleep(5000);return 41;
 }
 if(argc!=2||wcsncmp(argv[1],L"securerun-p09:",wcslen(L"securerun-p09:"))!=0)return 64;
 const WCHAR *nonce=argv[1]+wcslen(L"securerun-p09:");if(wcslen(nonce)!=36)return 64;
 for(int i=0;i<36;i++)if(!((nonce[i]>=L'0'&&nonce[i]<=L'9')||(nonce[i]>=L'a'&&nonce[i]<=L'f')||nonce[i]==L'-'))return 64;
 PWSTR base=NULL;if(SHGetKnownFolderPath(&FOLDERID_LocalAppData,0,NULL,&base)!=S_OK)return 65;
 WCHAR path[2048];int length=swprintf_s(path,2048,L"%ls\\SecureRunP09Protocol\\%ls.json",base,nonce);CoTaskMemFree(base);if(length<=0)return 65;
 HANDLE file=CreateFileW(path,GENERIC_WRITE,0,NULL,CREATE_NEW,FILE_ATTRIBUTE_NORMAL|FILE_FLAG_OPEN_REPARSE_POINT,NULL);if(file==INVALID_HANDLE_VALUE)return 66;
 const char *text=member()?"{\"invoked\":true,\"boxed\":true}":"{\"invoked\":true,\"boxed\":false}";
 DWORD written=0;BOOL ok=WriteFile(file,text,(DWORD)strlen(text),&written,NULL);FlushFileBuffers(file);CloseHandle(file);return ok?0:67;
}
