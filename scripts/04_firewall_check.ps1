# 04_firewall_check.ps1
# PhantomRPC Hardening -- Windows Firewall Verification (Read-Only)
# Reports firewall state across all profiles. Makes no changes.
#
# IMPORTANT: If any profile reports [FAIL] (firewall disabled), do NOT
# re-enable it without first understanding why it was turned off.
# Some POS systems, payment terminals, or receipt printer software
# disable the firewall as part of their installation. An IT professional
# should investigate before re-enabling.

#Requires -RunAsAdministrator

Write-Host "`n[*] Windows Firewall status check..." -ForegroundColor Cyan

try {
    $profiles = Get-NetFirewallProfile -ErrorAction Stop
} catch {
    Write-Host "[ERROR] Could not retrieve firewall profiles: $_" -ForegroundColor Red
    exit 1
}

$allEnabled = $true
foreach ($p in $profiles) {
    $status = if ($p.Enabled) { '[PASS]' } else { '[FAIL]' }
    $color  = if ($p.Enabled) { 'Green' } else { 'Red' }
    if (-not $p.Enabled) { $allEnabled = $false }
    $line = "  $status  Profile: $($p.Name) | Enabled: $($p.Enabled) | DefaultInbound: $($p.DefaultInboundAction)"
    Write-Host $line -ForegroundColor $color
}

Write-Host ""
if ($allEnabled) {
    Write-Host "[+] Windows Firewall is enabled on all profiles." -ForegroundColor Green
} else {
    Write-Host "[!] One or more firewall profiles are DISABLED." -ForegroundColor Red
    Write-Host "    DO NOT enable the firewall without IT review." -ForegroundColor Yellow
    Write-Host "    The firewall may be disabled intentionally by POS or printer software." -ForegroundColor Yellow
    Write-Host "    Note this finding and pass it to an IT professional." -ForegroundColor Yellow
}