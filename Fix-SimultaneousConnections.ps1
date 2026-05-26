param(
    [switch]$Restore
)

if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    $args = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    if ($Restore) { $args += " -Restore" }
    Start-Process powershell.exe -Verb RunAs -ArgumentList $args
    exit
}

$paths = @(
    "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WcmSvc\GroupPolicy",
    "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WcmSvc\LocalGroupPolicy"
)

$msg = if ($Restore) {
    foreach ($p in $paths) {
        if (Test-Path $p) { Remove-ItemProperty -Path $p -Name "fBlockNonDomain" -ErrorAction SilentlyContinue }
    }
    "Restored: fBlockNonDomain removed. Reverting WiFi metric..."
    Set-NetIPInterface -InterfaceAlias "Wi-Fi" -InterfaceMetric Auto -ErrorAction SilentlyContinue
    "Done. Simultaneous connection blocking may be re-enabled if set by Group Policy."
} else {
    foreach ($p in $paths) {
        if (-not (Test-Path $p)) { New-Item -Path $p -Force | Out-Null }
        Set-ItemProperty -Path $p -Name "fBlockNonDomain" -Value 0 -Type DWord
    }
    "Disabled: fBlockNonDomain = 0"
    $wifi = Get-NetIPInterface -InterfaceAlias "Wi-Fi" -ErrorAction SilentlyContinue
    if ($wifi) {
        Set-NetIPInterface -InterfaceAlias "Wi-Fi" -InterfaceMetric 1
        "WiFi metric set to 1 (highest priority)"
    } else {
        "WiFi interface not found – metric set skipped (rename 'Wi-Fi' if different)"
    }
    "Done. REBOOT recommended."
}

Write-Host $msg
Read-Host "Press Enter to exit"
