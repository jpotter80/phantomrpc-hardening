# 00_capture.ps1
# PhantomRPC Hardening — System Inventory
# Read-only. Makes no changes to the system.
# Output: ../output/capture-<COMPUTERNAME>-<DATETIME>.txt

#Requires -RunAsAdministrator

$timestamp  = Get-Date -Format 'yyyyMMdd-HHmm'
$outputDir  = Join-Path $PSScriptRoot '..\output'
$outputFile = Join-Path $outputDir "capture-$env:COMPUTERNAME-$timestamp.txt"

# Ensure output directory exists
if (-not (Test-Path $outputDir)) { New-Item -ItemType Directory -Path $outputDir | Out-Null }

function Write-Section {
    param([string]$Title)
    $line = '=' * 60
    "`n$line`n  $Title`n$line" | Tee-Object -FilePath $outputFile -Append | Write-Host -ForegroundColor Cyan
}

function Write-Out {
    param([string]$Text)
    $Text | Tee-Object -FilePath $outputFile -Append | Write-Host
}

# Header
$header = @"
PhantomRPC Hardening — System Capture
Computer : $env:COMPUTERNAME
Captured : $(Get-Date -Format 'yyyy-MM-dd HH:mm')
Operator : $env:USERNAME
"@
$header | Out-File -FilePath $outputFile -Encoding UTF8
Write-Host $header -ForegroundColor Yellow

# ── 1. System Information ───────────────────────────────────────────────────
Write-Section "1. SYSTEM INFORMATION"
$sysInfo = Get-ComputerInfo | Select-Object `
    CsName, WindowsProductName, WindowsVersion, OsBuildNumber,
    OsArchitecture, OsLastBootUpTime, CsManufacturer, CsModel
$sysInfo | Format-List | Out-String | Write-Out

# ── 2. Installed Hotfixes (last 30) ────────────────────────────────────────
Write-Section "2. INSTALLED HOTFIXES (most recent 30)"
$hotfixes = Get-HotFix | Sort-Object InstalledOn -Descending | Select-Object -First 30
$hotfixes | Format-Table HotFixID, Description, InstalledOn, InstalledBy -AutoSize | Out-String | Write-Out

$newest = $hotfixes | Select-Object -First 1
if ($newest.InstalledOn) {
    $age = (Get-Date) - $newest.InstalledOn
    Write-Out "Most recent patch age: $([int]$age.TotalDays) days"
    if ($age.TotalDays -gt 30) {
        Write-Out "[WARNING] Last patch is more than 30 days old — updates may be needed"
    }
}

# ── 3. Windows Update Service ───────────────────────────────────────────────
Write-Section "3. WINDOWS UPDATE SERVICE"
Get-Service -Name wuauserv | Select-Object Name, DisplayName, Status, StartType |
    Format-List | Out-String | Write-Out

# ── 4. PhantomRPC-Relevant Services ────────────────────────────────────────
Write-Section "4. PHANTOMRPC-RELEVANT SERVICES"
Write-Out "These four services are specifically named in the Kaspersky PhantomRPC report."
Write-Out "If any are Stopped when they should be running, their RPC endpoint can be hijacked.`n"
@('TermService','Dhcp','W32Time','WdiSystemHost') | ForEach-Object {
    try {
        Get-Service -Name $_ -ErrorAction Stop |
            Select-Object Name, DisplayName, Status, StartType |
            Format-Table -AutoSize | Out-String | Write-Out
    } catch {
        Write-Out "  [NOT FOUND] Service '$_' does not exist on this machine`n"
    }
}

# ── 5. All Running Services ─────────────────────────────────────────────────
Write-Section "5. ALL CURRENTLY RUNNING SERVICES"
Get-Service | Where-Object Status -eq 'Running' |
    Sort-Object Name |
    Format-Table Name, DisplayName, StartType -AutoSize | Out-String | Write-Out

# ── 6. Microsoft Defender Status ────────────────────────────────────────────
Write-Section "6. MICROSOFT DEFENDER STATUS"
try {
    $mp = Get-MpComputerStatus -ErrorAction Stop
    $checks = [ordered]@{
        'Real-Time Protection Enabled'  = $mp.RealTimeProtectionEnabled
        'Antivirus Enabled'             = $mp.AntivirusEnabled
        'Antispyware Enabled'           = $mp.AntispywareEnabled
        'Tamper Protection Active'      = $mp.IsTamperProtected
        'AM Service Enabled'            = $mp.AMServiceEnabled
        'NIS (Network Inspect) Enabled' = $mp.NISEnabled
    }
    foreach ($key in $checks.Keys) {
        $val    = $checks[$key]
        $status = if ($val) { '[PASS]' } else { '[FAIL]' }
        Write-Out "  $status  $key"
    }
    Write-Out ""
    Write-Out "  Antivirus Signature Last Updated : $($mp.AntivirusSignatureLastUpdated)"
    Write-Out "  AM Engine Version                : $($mp.AMEngineVersion)"
    Write-Out "  AM Product Version               : $($mp.AMProductVersion)"
} catch {
    Write-Out "  [ERROR] Could not retrieve Defender status: $_"
}

# ── 7. Windows Firewall Status ───────────────────────────────────────────────
Write-Section "7. WINDOWS FIREWALL STATUS"
try {
    $profiles = Get-NetFirewallProfile -ErrorAction Stop
    foreach ($p in $profiles) {
        $status = if ($p.Enabled) { '[PASS]' } else { '[FAIL]' }
        Write-Out "  $status  Profile: $($p.Name) — Enabled: $($p.Enabled) | DefaultInbound: $($p.DefaultInboundAction)"
    }
} catch {
    Write-Out "  [ERROR] Could not retrieve firewall status: $_"
}

# ── 8. Listening TCP Ports ───────────────────────────────────────────────────
Write-Section "8. LISTENING TCP PORTS"
Write-Out "Ports this machine is accepting inbound connections on:`n"
Get-NetTCPConnection -State Listen |
    Sort-Object LocalPort |
    Format-Table LocalAddress, LocalPort, OwningProcess -AutoSize | Out-String | Write-Out

Write-Out "Key ports to note:"
Write-Out "  135  = RPC Endpoint Mapper (used by PhantomRPC attack chain)"
Write-Out "  445  = SMB (file sharing; vector for many Windows exploits)"
Write-Out "  3389 = Remote Desktop (TermService; highest-value PhantomRPC target)"

# ── 9. Local Administrator Accounts ─────────────────────────────────────────
Write-Section "9. LOCAL ADMINISTRATOR ACCOUNTS"
Write-Out "All accounts with full administrator rights on this machine:`n"
try {
    Get-LocalGroupMember -Group 'Administrators' -ErrorAction Stop |
        Format-Table Name, ObjectClass, PrincipalSource -AutoSize | Out-String | Write-Out
} catch {
    Write-Out "  [ERROR] Could not retrieve Administrators group: $_"
}

# ── 10. SeImpersonatePrivilege ───────────────────────────────────────────────
Write-Section "10. SeImpersonatePrivilege ASSIGNMENTS"
Write-Out "This is the privilege PhantomRPC abuses. Normally only held by:"
Write-Out "  Administrators, LOCAL SERVICE, NETWORK SERVICE, SERVICE`n"
$tmpInf = Join-Path $env:TEMP "phantomrpc_secpol_$timestamp.inf"
try {
    secedit /export /cfg $tmpInf /areas USER_RIGHTS 2>$null | Out-Null
    $line = Select-String -Path $tmpInf -Pattern 'SeImpersonatePrivilege' | Select-Object -First 1
    if ($line) {
        Write-Out "  Raw policy line:"
        Write-Out "  $($line.Line)`n"
        Write-Out "  If this line contains SIDs beyond the four expected accounts,"
        Write-Out "  flag for an IT professional to investigate."
    } else {
        Write-Out "  SeImpersonatePrivilege not explicitly set (using system defaults — normal)."
    }
} catch {
    Write-Out "  [ERROR] Could not export security policy: $_"
} finally {
    if (Test-Path $tmpInf) { Remove-Item $tmpInf -Force }
}

# ── 11. Network Profile ──────────────────────────────────────────────────────
Write-Section "11. NETWORK CONNECTION PROFILES"
Write-Out "Network should be set to 'Private' for a trusted shop LAN, not 'Public'.`n"
try {
    Get-NetConnectionProfile -ErrorAction Stop |
        Format-Table Name, NetworkCategory, IPv4Connectivity, IPv6Connectivity -AutoSize |
        Out-String | Write-Out
} catch {
    Write-Out "  [ERROR] Could not retrieve network profiles: $_"
}

# ── Footer ───────────────────────────────────────────────────────────────────
$footer = "`n" + ('─' * 60) + "`nCapture complete. File saved to:`n$outputFile`n" + ('─' * 60)
$footer | Tee-Object -FilePath $outputFile -Append | Write-Host -ForegroundColor Green
