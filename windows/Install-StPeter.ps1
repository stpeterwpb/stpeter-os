# St. Peter OS - Windows side setup. Run ONCE on each classroom PC:
#   1. Copy the "windows" folder to the PC (USB stick is fine)
#   2. Right-click Install-StPeter.ps1 > Run with PowerShell  (approve the admin prompt)
#
# It adds a "Back to St. Peter" shortcut to every user's desktop and Start menu.
# Clicking it restarts the PC into St. Peter OS. No admin password needed to use it.

$ErrorActionPreference = 'Stop'

# --- Re-launch as administrator if needed ---
$me = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
if (-not $me.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process powershell.exe -Verb RunAs -ArgumentList `
        "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    exit
}

$dir      = Join-Path $env:ProgramData 'StPeter'
$script   = Join-Path $dir 'BackToStPeter.ps1'
$taskPath = '\StPeter\'
$taskName = 'Back to St. Peter'

Write-Host "Installing St. Peter switch..." -ForegroundColor Yellow
New-Item -ItemType Directory -Force -Path $dir | Out-Null
Copy-Item -Force (Join-Path $PSScriptRoot 'BackToStPeter.ps1') $script

# --- Scheduled task that does the switch with admin rights ---
$action = New-ScheduledTaskAction -Execute 'powershell.exe' `
    -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$script`""
$principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
$settings  = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 2)
Register-ScheduledTask -TaskName $taskName -TaskPath $taskPath -Action $action `
    -Principal $principal -Settings $settings -Force | Out-Null

# Let any signed-in user (including non-admin teacher accounts) start this one task
$svc = New-Object -ComObject 'Schedule.Service'
$svc.Connect()
$task = $svc.GetFolder($taskPath.TrimEnd('\')).GetTask($taskName)
$sd = $task.GetSecurityDescriptor(4)        # 4 = permissions (DACL) only
if ($sd -notmatch '\(A;;GRGX;;;AU\)') {
    $task.SetSecurityDescriptor($sd + '(A;;GRGX;;;AU)', 0)
}

# --- Shortcuts on every user's desktop and Start menu ---
$shell = New-Object -ComObject WScript.Shell
$targets = @(
    (Join-Path $env:PUBLIC 'Desktop\Back to St. Peter.lnk'),
    (Join-Path $env:ProgramData 'Microsoft\Windows\Start Menu\Programs\Back to St. Peter.lnk')
)
foreach ($lnk in $targets) {
    $s = $shell.CreateShortcut($lnk)
    $s.TargetPath   = Join-Path $env:SystemRoot 'System32\schtasks.exe'
    $s.Arguments    = "/run /tn `"$taskPath$taskName`""
    $s.WindowStyle  = 7   # minimized, so no black window flashes
    $s.IconLocation = (Join-Path $env:SystemRoot 'System32\shell32.dll') + ',27'
    $s.Description  = 'Restart into St. Peter OS'
    $s.Save()
}

# --- Turn off Fast Startup (recommended for PCs that switch between two systems) ---
New-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power' `
    -Name HiberbootEnabled -PropertyType DWord -Value 0 -Force | Out-Null

Write-Host ""
Write-Host "Done! 'Back to St. Peter' is on the desktop and in the Start menu." -ForegroundColor Green
Write-Host "Test it now: double-click it. The PC should restart into the St. Peter home screen."
Read-Host "Press Enter to close"
