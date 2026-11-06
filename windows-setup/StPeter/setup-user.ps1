# St. Peter OS - Windows setup, part 2 (runs once, at the Teacher account's first sign-in).
# Puts the finishing touches on, then tells St. Peter OS that Windows is ready and shuts down.
$ErrorActionPreference = 'Continue'
$sp = 'C:\StPeter'
curl.exe -s -m 5 -X POST http://10.0.2.100/phase/finish | Out-Null

# Wallpaper (again, in case Windows' first-sign-in theme replaced it)
Add-Type @'
using System.Runtime.InteropServices;
public class StPeterWall { [DllImport("user32.dll", CharSet = CharSet.Unicode)]
  public static extern int SystemParametersInfo(int a, int b, string c, int d); }
'@
[StPeterWall]::SystemParametersInfo(20, 0, "$sp\wallpaper.jpg", 3) | Out-Null

# Keyboards: English (US) and Arabic; Alt+Shift switches
try {
    $list = New-WinUserLanguageList en-US
    $list.Add('ar-EG')
    Set-WinUserLanguageList $list -Force
} catch { }

# OneDrive asks to sign in on every start; the classroom doesn't need it
foreach ($od in "$env:SystemRoot\System32\OneDriveSetup.exe", "$env:SystemRoot\SysWOW64\OneDriveSetup.exe") {
    if (Test-Path $od) { Start-Process $od '/uninstall' -Wait -ErrorAction SilentlyContinue; break }
}

# Never lock the screen or ask for a password on wake
powercfg.exe /SETACVALUEINDEX SCHEME_CURRENT SUB_NONE CONSOLELOCK 0

'St. Peter user setup finished ' + (Get-Date) | Out-File "$sp\setup-user.done"

# Tell St. Peter OS that Windows is ready, then shut down so it starts fresh next time.
curl.exe -s -m 5 -X POST http://10.0.2.100/installed | Out-Null
shutdown.exe /s /t 15 /c "St. Peter: Windows is ready. Shutting down for the first time."
