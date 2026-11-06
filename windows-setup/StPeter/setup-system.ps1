# St. Peter OS - Windows setup, part 1 (runs once as SYSTEM, before anyone signs in).
# Drivers, the "Back to St. Peter" button, St. Peter's look, and no ads or nagging.
$ErrorActionPreference = 'Continue'
$sp = 'C:\StPeter'

function Set-Reg($path, $name, $value, $type = 'DWord') {
    if (-not (Test-Path $path)) { New-Item -Path $path -Force | Out-Null }
    New-ItemProperty -Path $path -Name $name -Value $value -PropertyType $type -Force | Out-Null
}

# --- Virtual-machine drivers (display at full HD, network, memory, input) ---
Get-ChildItem "$sp\drivers" -Recurse -Filter *.inf -ErrorAction SilentlyContinue | ForEach-Object {
    pnputil.exe /add-driver $_.FullName /install | Out-Null
}

# --- The "Back to St. Peter" button (desktop, Start menu, taskbar) ---
# It asks St. Peter OS (at the VM's private address) to bring the St. Peter screen back.
$shell = New-Object -ComObject WScript.Shell
foreach ($lnk in @("$env:PUBLIC\Desktop\Back to St. Peter.lnk",
                   "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Back to St. Peter.lnk")) {
    $s = $shell.CreateShortcut($lnk)
    $s.TargetPath = "$env:SystemRoot\System32\conhost.exe"
    $s.Arguments = "--headless $env:SystemRoot\System32\curl.exe -s -m 5 -X POST http://10.0.2.100/hide"
    $s.IconLocation = "$sp\stpeter.ico,0"
    $s.Description = 'Go back to the St. Peter home screen (or press F12)'
    $s.WindowStyle = 7
    $s.Save()
}
$layoutDir = 'C:\Users\Default\AppData\Local\Microsoft\Windows\Shell'
New-Item -ItemType Directory -Force -Path $layoutDir | Out-Null
Copy-Item "$sp\LayoutModification.xml" "$layoutDir\LayoutModification.xml" -Force

# --- Look: St. Peter wallpaper and lock screen ---
$csp = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\PersonalizationCSP'
Set-Reg $csp 'LockScreenImagePath' "$sp\wallpaper.jpg" 'String'
Set-Reg $csp 'LockScreenImageUrl'  "$sp\wallpaper.jpg" 'String'
Set-Reg $csp 'LockScreenImageStatus' 1

# --- No ads, suggestions, widgets, Copilot, news, chat, or "finish setting up" ---
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent' 'DisableWindowsConsumerFeatures' 1
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent' 'DisableSoftLanding' 1
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent' 'DisableCloudOptimizedContent' 1
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Dsh' 'AllowNewsAndInterests' 0
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Chat' 'ChatIcon' 3
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot' 'TurnOffWindowsCopilot' 1
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search' 'AllowCortana' 0
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search' 'DisableWebSearch' 1
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer' 'DisableSearchBoxSuggestions' 1
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' 'AllowTelemetry' 1
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\OOBE' 'DisablePrivacyExperience' 1

# --- Microsoft Edge: St. Peter's website as the start page, no clutter ---
$edge = 'HKLM:\SOFTWARE\Policies\Microsoft\Edge'
Set-Reg $edge 'HideFirstRunExperience' 1
Set-Reg $edge 'NewTabPageContentEnabled' 0
Set-Reg $edge 'NewTabPageQuickLinksEnabled' 0
Set-Reg $edge 'NewTabPageHideDefaultTopSites' 1
Set-Reg $edge 'ShowRecommendationsEnabled' 0
Set-Reg $edge 'HubsSidebarEnabled' 0
Set-Reg $edge 'EdgeShoppingAssistantEnabled' 0
Set-Reg $edge 'PersonalizationReportingEnabled' 0
Set-Reg $edge 'DefaultBrowserSettingEnabled' 0
Set-Reg $edge 'HomepageLocation' 'https://stpeterwpb.org/en' 'String'
Set-Reg $edge 'RestoreOnStartup' 4
Set-Reg "$edge\RestoreOnStartupURLs" '1' 'https://stpeterwpb.org/en' 'String'

# --- Never sleep; Windows Update doesn't restart during the day ---
powercfg.exe /change standby-timeout-ac 0
powercfg.exe /change monitor-timeout-ac 0
powercfg.exe /hibernate off
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU' 'NoAutoRebootWithLoggedOnUsers' 1
Set-Reg 'HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings' 'ActiveHoursStart' 7
Set-Reg 'HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings' 'ActiveHoursEnd' 22
Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\Power' 'HiberbootEnabled' 0

# --- Settings for the Teacher account (applied to the default profile it is created from) ---
reg.exe load HKU\StPeterDefault C:\Users\Default\NTUSER.DAT | Out-Null
$u = 'Registry::HKEY_USERS\StPeterDefault'
$adv = "$u\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
Set-Reg $adv 'TaskbarDa' 0                  # widgets
Set-Reg $adv 'TaskbarMn' 0                  # chat
Set-Reg $adv 'ShowTaskViewButton' 0
Set-Reg $adv 'ShowCopilotButton' 0
Set-Reg $adv 'Start_IrisRecommendations' 0
Set-Reg $adv 'Start_TrackDocs' 0
Set-Reg "$u\Software\Microsoft\Windows\CurrentVersion\Search" 'SearchboxTaskbarMode' 1
$cdm = "$u\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
foreach ($n in 'SilentInstalledAppsEnabled','SystemPaneSuggestionsEnabled','SoftLandingEnabled','RotatingLockScreenEnabled',
               'RotatingLockScreenOverlayEnabled','SubscribedContent-310093Enabled','SubscribedContent-338388Enabled',
               'SubscribedContent-338389Enabled','SubscribedContent-338393Enabled','SubscribedContent-353694Enabled',
               'SubscribedContent-353696Enabled','PreInstalledAppsEnabled','OemPreInstalledAppsEnabled','ContentDeliveryAllowed') {
    Set-Reg $cdm $n 0
}
Set-Reg "$u\Software\Microsoft\Windows\CurrentVersion\UserProfileEngagement" 'ScoobeSystemSettingEnabled' 0
Set-Reg "$u\Software\Policies\Microsoft\Windows\WindowsCopilot" 'TurnOffWindowsCopilot' 1
# St. Peter maroon as the accent color on the taskbar and window borders (AABBGGRR)
Set-Reg "$u\Software\Microsoft\Windows\DWM" 'AccentColor' 0xFF1A0F5C
Set-Reg "$u\Software\Microsoft\Windows\DWM" 'ColorPrevalence' 1
Set-Reg "$u\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" 'ColorPrevalence' 1
Set-Reg "$u\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" 'SystemUsesLightTheme' 0
Set-Reg "$u\Control Panel\Desktop" 'Wallpaper' "$sp\wallpaper.jpg" 'String'
Set-Reg "$u\Control Panel\Desktop" 'WallpaperStyle' '10' 'String'
Remove-ItemProperty -Path "$u\Software\Microsoft\Windows\CurrentVersion\Run" -Name 'OneDriveSetup' -ErrorAction SilentlyContinue
[gc]::Collect(); Start-Sleep -Seconds 2
reg.exe unload HKU\StPeterDefault | Out-Null

'St. Peter system setup finished ' + (Get-Date) | Out-File "$sp\setup-system.done"
