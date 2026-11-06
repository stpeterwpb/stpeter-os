# St. Peter OS - "Back to St. Peter"
# Restarts this PC into St. Peter OS (the Linux SSD).
# Installed by Install-StPeter.ps1 and run as a scheduled task with admin rights,
# so it works from a normal (non-admin) Windows account without a UAC prompt.

$log = Join-Path $env:ProgramData 'StPeter\back.log'

try {
    # Find the St. Peter OS (Debian) entry in the PC's firmware boot list
    $text   = (bcdedit /enum firmware) -join "`n"
    $blocks = $text -split "`n\s*`n"
    $id = $null
    foreach ($b in $blocks) {
        if ($b -match '(?im)^description\s+(debian|st\.? ?peter)') {
            if ($b -match '(?im)^identifier\s+(\{[0-9a-f-]+\})') { $id = $Matches[1]; break }
        }
    }
    if ($id) {
        # Boot St. Peter OS on the next restart only (even if a Windows update
        # moved Windows to the front of the boot order)
        bcdedit /set '{fwbootmgr}' bootsequence $id | Out-Null
        "$(Get-Date -Format s)  next boot: $id" | Out-File $log -Append -Encoding ascii
    } else {
        "$(Get-Date -Format s)  St. Peter OS entry not found; restarting with normal boot order" |
            Out-File $log -Append -Encoding ascii
    }
} catch {
    "$(Get-Date -Format s)  $_" | Out-File $log -Append -Encoding ascii
}

# Restart now. Open programs are closed; unsaved work is lost, as with any restart.
shutdown.exe /r /t 0 /f
