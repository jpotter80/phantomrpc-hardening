# 01_windows_update.ps1
# PhantomRPC Hardening — Install Windows Updates
# WARNING: This script may automatically reboot the machine if a patch requires it.
# Save all open work before running.

#Requires -RunAsAdministrator

Write-Host "`n[*] Windows Update — starting..." -ForegroundColor Cyan

# Step 1: Ensure the Windows Update service is set to Automatic
Write-Host "[*] Setting Windows Update service (wuauserv) to Automatic start..."
Set-Service -Name wuauserv -StartupType Automatic
Start-Service -Name wuauserv -ErrorAction SilentlyContinue
Write-Host "[+] Windows Update service is Automatic and running."

# Step 2: Install PSWindowsUpdate module if not already present
# PSWindowsUpdate is a well-established community module that wraps the
# Windows Update API cleanly. Source: PSGallery (official PowerShell repository).
if (-not (Get-Module -ListAvailable -Name PSWindowsUpdate)) {
    Write-Host "[*] PSWindowsUpdate module not found. Installing..."

    # Ensure NuGet package provider is available (required by Install-Module)
    Write-Host "[*] Ensuring NuGet provider is available..."
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Scope AllUsers | Out-Null

    # Trust PSGallery so Install-Module doesn't prompt interactively
    Set-PSRepository -Name PSGallery -InstallationPolicy Trusted

    Install-Module -Name PSWindowsUpdate -Force -SkipPublisherCheck -Scope AllUsers
    Write-Host "[+] PSWindowsUpdate installed."
} else {
    Write-Host "[+] PSWindowsUpdate module already present."
}

Import-Module PSWindowsUpdate

# Step 3: Show available updates before installing
Write-Host "`n[*] Checking for available updates..."
$available = Get-WindowsUpdate -AcceptAll -IgnoreReboot
if ($available.Count -eq 0) {
    Write-Host "[+] No updates available. Machine is fully patched." -ForegroundColor Green
    exit 0
}

Write-Host "`n[*] Updates found: $($available.Count)"
$available | Format-Table KB, Size, Title -AutoSize

# Step 4: Download and install all updates
# -AcceptAll     : accepts all EULAs without prompting
# -AutoReboot    : reboots automatically if required by a patch
# -Verbose       : shows download/install progress
Write-Host "`n[*] Installing updates. The machine may reboot automatically..." -ForegroundColor Yellow
Install-WindowsUpdate -AcceptAll -AutoReboot -Verbose
