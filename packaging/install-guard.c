/* Fixed-path setup preflight, not a service or privileged product helper.
   Compile natively /MT; never consume profile, engine or actor-supplied paths. */
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <aclapi.h>
#include <sddl.h>
#include <shlobj.h>
#include <strsafe.h>
#include <stdio.h>
#pragma comment(lib,"advapi32.lib")
#pragma comment(lib,"shell32.lib")
#pragma comment(lib,"ole32.lib")
#pragma comment(lib,"uuid.lib")
static BOOL privileged(PSID sid) {
    PSID admins=NULL,system=NULL,installer=NULL;
    BOOL result=FALSE;
    if(ConvertStringSidToSidW(L"S-1-5-32-544",&admins) &&
       ConvertStringSidToSidW(L"S-1-5-18",&system) &&
       ConvertStringSidToSidW(L"S-1-5-80-956008885-3418522649-1831038044-1853292631-2271478464",&installer))
        result=EqualSid(sid,admins)||EqualSid(sid,system)||EqualSid(sid,installer);
    LocalFree(admins);LocalFree(system);LocalFree(installer);return result;
}
static BOOL checked_path(const wchar_t *path, ACCESS_MASK denied_writes) {
    HANDLE f=CreateFileW(path,READ_CONTROL|FILE_READ_ATTRIBUTES,FILE_SHARE_READ|FILE_SHARE_WRITE,
        NULL,OPEN_EXISTING,FILE_FLAG_BACKUP_SEMANTICS|FILE_FLAG_OPEN_REPARSE_POINT,NULL);
    BY_HANDLE_FILE_INFORMATION info;PSID owner=NULL;PACL dacl=NULL;PSECURITY_DESCRIPTOR sd=NULL;
    BOOL ok=FALSE;
    if(f==INVALID_HANDLE_VALUE)return FALSE;
    if(!GetFileInformationByHandle(f,&info)||(info.dwFileAttributes&FILE_ATTRIBUTE_REPARSE_POINT))goto end;
    if(GetSecurityInfo(f,SE_FILE_OBJECT,OWNER_SECURITY_INFORMATION|DACL_SECURITY_INFORMATION,
        &owner,NULL,&dacl,NULL,&sd)!=ERROR_SUCCESS||!owner||!dacl||!privileged(owner)||dacl->AceCount>256)goto end;
    for(DWORD i=0;i<dacl->AceCount;i++) {
        void *raw=NULL;if(!GetAce(dacl,i,&raw))goto end;
        ACE_HEADER *h=(ACE_HEADER*)raw;if(h->AceFlags&INHERIT_ONLY_ACE)continue;
        if(h->AceType==ACCESS_ALLOWED_ACE_TYPE) {
            ACCESS_ALLOWED_ACE *a=(ACCESS_ALLOWED_ACE*)raw;
            if((a->Mask&denied_writes)&&!privileged(&a->SidStart))goto end;
        } else if(h->AceType!=ACCESS_DENIED_ACE_TYPE)goto end;
    }
    ok=TRUE;
end: LocalFree(sd);CloseHandle(f);return ok;
}
static BOOL protected_path(const wchar_t *path) {
    return checked_path(path,GENERIC_ALL|GENERIC_WRITE|DELETE|WRITE_DAC|WRITE_OWNER|0x156);
}
static BOOL protected_ancestor(const wchar_t *path) {
    /* FILE_DELETE_CHILD on a parent can authorize replacement despite a child's
       own DACL. Windows volume roots may legitimately allow creation of new
       subdirectories; that does not authorize replacing existing code ancestry.
       Reject ancestor mutation/ownership rights, but allow that creation right. */
    return checked_path(path,GENERIC_ALL|GENERIC_WRITE|DELETE|WRITE_DAC|WRITE_OWNER|
        FILE_DELETE_CHILD|FILE_WRITE_ATTRIBUTES|FILE_WRITE_EA);
}
static BOOL tree(const wchar_t *path, unsigned depth, unsigned *count) {
    wchar_t pattern[1024],child[1024];WIN32_FIND_DATAW data;
    if(depth>4||!protected_path(path)||FAILED(StringCchPrintfW(pattern,1024,L"%s\\*",path)))return FALSE;
    HANDLE find=FindFirstFileW(pattern,&data);if(find==INVALID_HANDLE_VALUE)return GetLastError()==ERROR_FILE_NOT_FOUND;
    BOOL ok=TRUE;
    do {
        if(!wcscmp(data.cFileName,L".")||!wcscmp(data.cFileName,L".."))continue;
        if(++*count>512||(data.dwFileAttributes&FILE_ATTRIBUTE_REPARSE_POINT)||
           FAILED(StringCchPrintfW(child,1024,L"%s\\%s",path,data.cFileName))||!protected_path(child)) {ok=FALSE;break;}
        if((data.dwFileAttributes&FILE_ATTRIBUTE_DIRECTORY)&&!tree(child,depth+1,count)){ok=FALSE;break;}
    } while(FindNextFileW(find,&data));
    DWORD error=GetLastError();FindClose(find);return ok&&error==ERROR_NO_MORE_FILES;
}
int wmain(int argc,wchar_t **argv) {
    if(argc!=2||wcscmp(argv[1],L"preflight"))return 64;
    if(GetModuleHandleW(L"SbieDll.dll"))return 78;
    PWSTR pf=NULL;wchar_t root[1024],parent[1024],volume[16],fs[32];unsigned count=0;
    if(FAILED(SHGetKnownFolderPath(&FOLDERID_ProgramFiles,0,NULL,&pf)))return 65;
    BOOL ok=SUCCEEDED(StringCchCopyW(parent,1024,pf))&&protected_path(parent)&&
        SUCCEEDED(StringCchPrintfW(root,1024,L"%s\\SecureRun Development",pf));CoTaskMemFree(pf);
    if(!ok)return 66;
    /* Check every ancestor, including the volume root. */
    while(wcslen(parent)>3) {
        wchar_t *slash=wcsrchr(parent,L'\\');if(!slash)return 66;
        if(slash==parent+2)slash[1]=0;else *slash=0;
        DWORD attr=GetFileAttributesW(parent);
        if(attr==INVALID_FILE_ATTRIBUTES||(attr&FILE_ATTRIBUTE_REPARSE_POINT)||!protected_ancestor(parent))return 66;
    }
    if(!GetVolumePathNameW(root,volume,16)||!GetVolumeInformationW(volume,NULL,0,NULL,NULL,NULL,fs,32)||
       _wcsicmp(fs,L"NTFS")||GetDriveTypeW(volume)!=DRIVE_FIXED)return 67;
    DWORD attrs=GetFileAttributesW(root);
    if(attrs==INVALID_FILE_ATTRIBUTES) {
        if(GetLastError()!=ERROR_FILE_NOT_FOUND&&GetLastError()!=ERROR_PATH_NOT_FOUND)return 68;
        if(!CreateDirectoryW(root,NULL))return 68;
    } else if(!(attrs&FILE_ATTRIBUTE_DIRECTORY))return 68;
    if(!tree(root,0,&count))return 69;
    puts("INSTALL_PATH_PROTECTED");return 0;
}
