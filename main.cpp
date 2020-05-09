#include "easyhook.h"
#include <windows.h>
#include <string>
#include <strsafe.h>

#pragma comment(lib, "Psapi.lib")
#pragma comment(lib, "Aux_ulib.lib")
#ifndef _WIN64 
#pragma comment(lib, "easyhk32.lib")
#else
#pragma comment(lib, "easyhk64.lib")
#endif

// define ORIG_* variables
#define HOOK_DEFINE(rettype, name, argtype) \
	rettype (WINAPI * ORIG_##name) argtype;
#include "hooklist.h"
#undef HOOK_DEFINE

// define HOOK_* structures
#define HOOK_DEFINE(rettype, name, argtype) \
	HOOK_TRACE_INFO HOOK_##name = {0};
#include "hooklist.h"
#undef HOOK_DEFINE

// install hooks
#define FORCE(expr) {if(!SUCCEEDED(NtStatus = (expr))) goto ERROR_ABORT;}
#define HOOK_DEFINE(rettype, name, argtype) \
	if (&ORIG_##name) { \
	FORCE(LhInstallHook((PVOID&)ORIG_##name, IMPL_##name, (PVOID)0, &HOOK_##name)); \
	*(void**)&ORIG_##name =  (void*)HOOK_##name.Link->OldProc; \
	FORCE(LhSetExclusiveACL(ACLEntries, 0, &HOOK_##name)); }

static LONG hook_init()
{
	ULONG ACLEntries[1] = { 0 };
	NTSTATUS NtStatus;

#include "hooklist.h"

#undef HOOK_DEFINE

	FORCE(LhSetGlobalExclusiveACL(ACLEntries, 0));
	return NOERROR;

ERROR_ABORT:
	return 1;
}
#undef HOOK_DEFINE

// assign ORIG_* to original function pointers
#define HOOK_DEFINE(rettype, name, argtype) \
	ORIG_##name = name;
#pragma optimize("s", on)
static LONG hook_term()
{
#include "hooklist.h"
	LhUninstallAllHooks();
	return LhWaitForPendingRemovals();
}
#pragma optimize("", on)
#undef HOOK_DEFINE

int __stdcall DllMain(_In_ HINSTANCE hInstance, _In_ DWORD fdwReason, _In_ LPVOID lpvReserved) {
	static bool bHookInited = false;
	if (!EasyHookDllMain(hInstance, fdwReason, lpvReserved))
		return false;

	switch (fdwReason) {
	case DLL_PROCESS_ATTACH:
	{
		DisableThreadLibraryCalls(hInstance);
		if (!GetModuleHandle(L"MacType.core.dll") && !GetModuleHandle(L"MacType.core64.dll")) {
			hook_init();
			bHookInited = true;
		}
		return true;
	}
	case DLL_PROCESS_DETACH:
	{
		if (bHookInited)
			hook_term();
		return true;
	}

	default:
		return true;
	}
}

#pragma pack(push)
#pragma pack(1)
typedef struct {
	WCHAR FontWanted[LF_FACESIZE];
	WCHAR FontCreated[LF_FACESIZE];
} FONTINFO, *PFONTINFO;
#pragma pack(pop)

HWND g_WndObserver = NULL;
const int CDMagic = 0x12344321;
void TellObserver(std::wstring szFontName, std::wstring szResult) {
	if (!g_WndObserver) {
		g_WndObserver = FindWindow(L"TWhichFontFather", NULL);
	}
	if (g_WndObserver) {
		FONTINFO fonts = {0};
		StringCchCopy(fonts.FontWanted, LF_FACESIZE, szFontName.c_str());
		StringCchCopy(fonts.FontCreated, LF_FACESIZE, szResult.c_str());
		COPYDATASTRUCT cds = { CDMagic, sizeof FONTINFO, &fonts };
		SendMessage(g_WndObserver, WM_COPYDATA, 0, (int)&cds);
	}
}

HFONT WINAPI IMPL_CreateFontIndirectExW(CONST ENUMLOGFONTEXDV *penumlfex)
{
	HFONT ret = ORIG_CreateFontIndirectExW(penumlfex);
	if (penumlfex && ret) {
		std::wstring fname = penumlfex->elfEnumLogfontEx.elfLogFont.lfFaceName;
		LOGFONT lf = { 0 };
		GetObject(ret, sizeof(LOGFONT), &lf);	// get the font actually been created.
		std::wstring fretname = lf.lfFaceName;
		TellObserver(fname, fretname);
	}
	return ret;
}