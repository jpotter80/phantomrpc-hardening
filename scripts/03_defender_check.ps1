# 03_defender_check.ps1
# PhantomRPC Hardening — Microsoft Defender Verification (Read-Only)
# Reports Defender status. Makes no changes.
# Any [FAIL] items should be reviewed by an IT professional.

#Requires -RunAsAdministrator

Write-Host "`n[*] Microsoft Defender status check..." -ForegroundColor Cyan

try {
    $mp = Get-MpComputerStatus -ErrorAction Stop
} catch {
    Write-Host "[ERROR] Could not retrieve Defender status: $_" -ForegroundColor Red
    exit 1
}

$checks = [ordered]@{
    'Real-Time Protection Enabled'  = $mp.RealTimeProtectionEnabled
    'Antivirus Enabled'             = $mp.AntivirusEnabled
    'Antispyware Enabled'           = $mp.AntispywareEnabled
    'Tamper Protection Active'      = $mp.IsTamperProtected
    'AM Service Enabled'            = $mp.AMServiceEnabled
    'NIS (Network Inspect) Enabled' = $mp.NISEnabled
}

$allPass = $true
foreach ($key in $checks.Keys) {
    $val    = $checks[$key]
    $status = if ($val) { '[PASS]' } else { '[FAIL]'; $allPass = $false }
    $color  = if ($val) { 'Green' } else { 'Red' }
    Write-Host "  $status  $key" -ForegroundColor $color
}

Write-Host ""
Write-Host "  Signature Last Updated : $($mp.AntivirusSignatureLastUpdated)"
Write-Host "  Engine Version         : $($mp.AMEngineVersion)"
Write-Host "  Product Version        : $($mp.AMProductVersion)"

Write-Host ""
if ($allPass) {
    Write-Host "[+] Defender is fully enabled and healthy." -ForegroundColor Green
} else {
    Write-Host "[!] One or more Defender checks FAILED." -ForegroundColor Red
    Write-Host "    Do not attempt to fix these settings manually." -ForegroundColor Yellow
    Write-Host "    Note the [FAIL] items and pass them to an IT professional." -ForegroundColor Yellow
}
