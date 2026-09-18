// ---------------------------------------------------------------------------
// excalibur-launcher - startar Excalibur, eller fokuserar den redan körande.
//
// Tänkt att bindas till calc-knappen på tangentbordet (VK_LAUNCH_APP2) via
// HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\AppKey\18.
//
// Excalibur registrerar fönsterklassen "EXCALIBUR" (src/Excal.c) och har ingen
// egen instanskontroll. Vi matchar på klassnamnet, inte på fönstertiteln -
// titeln byts ut mot X-registrets värde när fönstret minimeras.
// ---------------------------------------------------------------------------
#include <windows.h>

#define TARGET_EXE   "Excal32.exe"
#define WINDOW_CLASS "EXCALIBUR"
#define MUTEX_NAME   "Local\\ExcaliburLauncherSingleton"

// SetForegroundWindow tystnar om anroparen saknar förgrundsrätt. Att koppla
// vår indatakö till den nuvarande förgrundstrådens ger oss rätten.
static void ForceForeground(HWND hwnd)
{
    DWORD fgTid = GetWindowThreadProcessId(GetForegroundWindow(), NULL);
    DWORD myTid = GetCurrentThreadId();
    BOOL attached = FALSE;

    if (fgTid && fgTid != myTid)
        attached = AttachThreadInput(myTid, fgTid, TRUE);

    ShowWindow(hwnd, IsIconic(hwnd) ? SW_RESTORE : SW_SHOW);
    BringWindowToTop(hwnd);
    SetForegroundWindow(hwnd);
    SetActiveWindow(hwnd);

    if (attached)
        AttachThreadInput(myTid, fgTid, FALSE);
}

// Bygger sökvägen till Excal32.exe i samma katalog som launchern.
static BOOL BuildTargetPath(char *path, char *dir, DWORD dirSize)
{
    DWORD len = GetModuleFileNameA(NULL, dir, dirSize);
    char *slash;

    if (len == 0 || len >= dirSize)
        return FALSE;

    slash = dir;
    for (char *p = dir; *p; p++)
        if (*p == '\\' || *p == '/')
            slash = p;
    *slash = '\0';

    if (wsprintfA(path, "%s\\%s", dir, TARGET_EXE) <= 0)
        return FALSE;

    return TRUE;
}

int WINAPI WinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance, LPSTR lpCmdLine, int nCmdShow)
{
    char exePath[MAX_PATH * 2];
    char exeDir[MAX_PATH];
    HANDLE mutex;
    HWND hwnd;
    STARTUPINFOA si;
    PROCESS_INFORMATION pi;

    (void)hInstance; (void)hPrevInstance; (void)lpCmdLine; (void)nCmdShow;

    // Serialiserar snabba dubbeltryck: nästa launcher väntar tills den förra
    // hunnit få upp fönstret, och ser det då i stället för att starta en till.
    mutex = CreateMutexA(NULL, FALSE, MUTEX_NAME);
    if (mutex)
        WaitForSingleObject(mutex, 10000);

    hwnd = FindWindowA(WINDOW_CLASS, NULL);
    if (hwnd)
    {
        ForceForeground(hwnd);
        if (mutex) { ReleaseMutex(mutex); CloseHandle(mutex); }
        return 0;
    }

    if (!BuildTargetPath(exePath, exeDir, sizeof(exeDir)))
    {
        MessageBoxA(NULL, "Kunde inte ta reda på var launchern ligger.",
                    "Excalibur", MB_OK | MB_ICONERROR);
        if (mutex) { ReleaseMutex(mutex); CloseHandle(mutex); }
        return 1;
    }

    ZeroMemory(&si, sizeof(si));
    si.cb = sizeof(si);
    ZeroMemory(&pi, sizeof(pi));

    if (!CreateProcessA(exePath, NULL, NULL, NULL, FALSE, 0, NULL, exeDir, &si, &pi))
    {
        char msg[MAX_PATH * 2 + 128];
        wsprintfA(msg, "Hittar inte räknaren:\n%s\n\nLägg Excal32.exe i samma mapp som launchern.", exePath);
        MessageBoxA(NULL, msg, "Excalibur", MB_OK | MB_ICONERROR);
        if (mutex) { ReleaseMutex(mutex); CloseHandle(mutex); }
        return 1;
    }

    // Håll mutexen tills fönstret finns, annars hinner ett andra tryck starta
    // en till instans innan den första registrerat sitt fönster.
    WaitForInputIdle(pi.hProcess, 10000);
    CloseHandle(pi.hThread);
    CloseHandle(pi.hProcess);

    if (mutex) { ReleaseMutex(mutex); CloseHandle(mutex); }
    return 0;
}
