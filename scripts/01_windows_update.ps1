# 01_windows_update.ps1
# PhantomRPC Hardening -- Install Windows Updates
# WARNING: This script may automatically reboot the machine if a patch requires it.
# Save all open work before running.

#Requires -RunAsAdministrator

Write-Host "`n[*] Windows Update -- starting..." -ForegroundColor Cyan

# Step 1: Ensure the Windows Update service is set to Automatic
Write-Host "[*] Setting Windows Update service (wuauserv) to Automatic start..."
Set-Service -Name wuauserv -StartupType Automatic
Start-Service -Name wuauserv -ErrorAction SilentlyContinue
Write-Host "[+] Windows Update service is Automatic and running."

# Step 2: Trigger a full scan via UsoClient.
# UsoClient is the same Update Session Orchestrator that the Settings GUI uses
# internally. Running StartScan here ensures Windows sees everything Settings
# would see, including feature/version upgrade offers.
Write-Host "[*] Triggering full update scan via UsoClient (this may take a moment)..."
Start-Process -FilePath "UsoClient.exe" -ArgumentList "StartScan" -Wait -NoNewWindow
Start-Sleep -Seconds 15
Write-Host "[+] UsoClient scan triggered."

# Step 3: Install PSWindowsUpdate module if not already present.
# PSWindowsUpdate wraps the Windows Update Agent API and allows scripted installs.
if (-not (Get-Module -ListAvailable -Name PSWindowsUpdate)) {
    Write-Host "[*] PSWindowsUpdate module not found. Installing..."
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Scope AllUsers | Out-Null
    Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
    Install-Module -Name PSWindowsUpdate -Force -SkipPublisherCheck -Scope AllUsers
    Write-Host "[+] PSWindowsUpdate installed."
} else {
    Write-Host "[+] PSWindowsUpdate module already present."
}

Import-Module PSWindowsUpdate

# Step 4: Register the Microsoft Update service.
# This is the broader endpoint that includes feature updates and upgrades --
# the same source the Settings GUI draws from. Without this, only the narrower
# Windows Update endpoint is queried and major version upgrades may be missed.
Write-Host "[*] Registering Microsoft Update service..."
Add-WUServiceManager -MicrosoftUpdate -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
Write-Host "[+] Microsoft Update service registered."

# Step 5: Check for available updates across all categories
Write-Host "`n[*] Checking for available updates (all categories)..."
$available = Get-WindowsUpdate -MicrosoftUpdate -AcceptAll -IgnoreReboot
if ($available.Count -eq 0) {
    Write-Host "[+] No updates available. Machine is fully patched." -ForegroundColor Green
    exit 0
}

Write-Host "`n[*] Updates found: $($available.Count)"
$available | Format-Table KB, Size, Title -AutoSize

# Step 6: Download and install all updates.
# -MicrosoftUpdate : queries the full Microsoft Update catalog including upgrades
# -AcceptAll       : accepts all EULAs without prompting
# -AutoReboot      : reboots automatically if required by a patch
Write-Host "`n[*] Installing updates. The machine may reboot automatically..." -ForegroundColor Yellow
Install-WindowsUpdate -MicrosoftUpdate -AcceptAll -AutoReboot -Verbose
