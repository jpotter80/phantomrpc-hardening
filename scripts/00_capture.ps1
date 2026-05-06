# 00_capture.ps1
# PhantomRPC Hardening -- System Inventory
# Read-only. Makes no changes to the system.
# Output: ..\output\capture-<COMPUTERNAME>-<DATETIME>.txt

#Requires -RunAsAdministrator

$timestamp  = Get-Date -Format 'yyyyMMdd-HHmm'
$outputDir  = Join-Path $PSScriptRoot '..\output'
$outputFile = Join-Path $outputDir "capture-$env:COMPUTERNAME-$timestamp.txt"

if (-not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir | Out-Null
}

function Write-Section {
    param([string]$Title)
    $line  = '=' * 60
    $block = "`n$line`n  $Title`n$line"
    $block | Out-File -FilePath $outputFile -Append -Encoding UTF8
    Write-Host $block -ForegroundColor Cyan
}

function Write-Out {
    param([string]$Text)
    $Text | Out-File -FilePath $outputFile -Append -Encoding UTF8
    Write-Host $Text
}

# Header
$header = @"
PhantomRPC Hardening -- System Capture
Computer : $env:COMPUTERNAME
Captured : $(Get-Date -Format 'yyyy-MM-dd HH:mm')
Operator : $env:USERNAME
"@
$header | Out-File -FilePath $outputFile -Encoding UTF8
Write-Host $header -ForegroundColor Yellow

# -- 1. System Information ------------------------------------------------
Write-Section "1. SYSTEM INFORMATION"
$sysInfo = Get-ComputerInfo | Select-Object `
    CsName, WindowsProductName, WindowsVersion, OsBuildNumber,
    OsArchitecture, OsLastBootUpTime, CsManufacturer, CsModel
Write-Out ($sysInfo | Format-List | Out-String)

# -- 2. Installed Hotfixes (last 30) --------------------------------------
Write-Section "2. INSTALLED HOTFIXES (most recent 30)"
$hotfixes = Get-HotFix | Sort-Object InstalledOn -Descending | Select-Object -First 30
Write-Out ($hotfixes | Format-Table HotFixID, Description, InstalledOn, InstalledBy -AutoSize | Out-String)

$newest = $hotfixes | Select-Object -First 1
if ($newest.InstalledOn) {
    $age = (Get-Date) - $newest.InstalledOn
    Write-Out "Most recent patch age: $([int]$age.TotalDays) days"
    if ($age.TotalDays -gt 30) {
        Write-Out "[WARNING] Last patch is more than 30 days old -- updates may be needed"
    }
}

# -- 3. Windows Update Service --------------------------------------------
Write-Section "3. WINDOWS UPDATE SERVICE"
$wuSvc = Get-Service -Name wuauserv | Select-Object Name, DisplayName, Status, StartType
Write-Out ($wuSvc | Format-List | Out-String)

# -- 4. PhantomRPC-Relevant Services --------------------------------------
Write-Section "4. PHANTOMRPC-RELEVANT SERVICES"
Write-Out "These four services are named in the Kaspersky PhantomRPC report."
Write-Out "If stopped, their RPC endpoint can be hijacked by an attacker."
Write-Out ""
@('TermService','Dhcp','W32Time','WdiSystemHost') | ForEach-Object {
    try {
        $svc = Get-Service -Name $_ -ErrorAction Stop |
            Select-Object Name, DisplayName, Status, StartType
        Write-Out ($svc | Format-Table -AutoSize | Out-String)
    } catch {
        Write-Out "  [NOT FOUND] Service '$_' does not exist on this machine"
        Write-Out ""
    }
}

# -- 5. All Running Services ----------------------------------------------
Write-Section "5. ALL CURRENTLY RUNNING SERVICES"
$runningSvcs = Get-Service | Where-Object Status -eq 'Running' | Sort-Object Name
Write-Out ($runningSvcs | Format-Table Name, DisplayName, StartType -AutoSize | Out-String)

# -- 6. Microsoft Defender Status -----------------------------------------
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

# -- 7. Windows Firewall Status -------------------------------------------
Write-Section "7. WINDOWS FIREWALL STATUS"
try {
    $fwProfiles = Get-NetFirewallProfile -ErrorAction Stop
    foreach ($p in $fwProfiles) {
        $status = if ($p.Enabled) { '[PASS]' } else { '[FAIL]' }
        $line   = "  $status  Profile: $($p.Name) | Enabled: $($p.Enabled) | DefaultInbound: $($p.DefaultInboundAction)"
        Write-Out $line
    }
} catch {
    Write-Out "  [ERROR] Could not retrieve firewall status: $_"
}

# -- 8. Listening TCP Ports -----------------------------------------------
Write-Section "8. LISTENING TCP PORTS"
Write-Out "Ports this machine is accepting inbound connections on:"
Write-Out ""
$listeners = Get-NetTCPConnection -State Listen | Sort-Object LocalPort
Write-Out ($listeners | Format-Table LocalAddress, LocalPort, OwningProcess -AutoSize | Out-String)
Write-Out "Key ports to note:"
Write-Out "  135  = RPC Endpoint Mapper (used by PhantomRPC attack chain)"
Write-Out "  445  = SMB (file sharing -- vector for many Windows exploits)"
Write-Out "  3389 = Remote Desktop (TermService -- highest-value PhantomRPC target)"

# -- 9. Local Administrator Accounts --------------------------------------
Write-Section "9. LOCAL ADMINISTRATOR ACCOUNTS"
Write-Out "All accounts with full administrator rights on this machine:"
Write-Out ""
try {
    $admins = Get-LocalGroupMember -Group 'Administrators' -ErrorAction Stop
    Write-Out ($admins | Format-Table Name, ObjectClass, PrincipalSource -AutoSize | Out-String)
} catch {
    Write-Out "  [ERROR] Could not retrieve Administrators group: $_"
}

# -- 10. SeImpersonatePrivilege -------------------------------------------
Write-Section "10. SeImpersonatePrivilege ASSIGNMENTS"
Write-Out "This is the privilege PhantomRPC abuses. Should only be held by:"
Write-Out "  Administrators, LOCAL SERVICE, NETWORK SERVICE, SERVICE"
Write-Out ""
$tmpInf = Join-Path $env:TEMP "phantomrpc_secpol_$timestamp.inf"
try {
    secedit /export /cfg $tmpInf /areas USER_RIGHTS 2>$null | Out-Null
    $match = Select-String -Path $tmpInf -Pattern 'SeImpersonatePrivilege' |
        Select-Object -First 1
    if ($match) {
        Write-Out "  Raw policy line:"
        Write-Out "  $($match.Line)"
        Write-Out ""
        Write-Out "  If this contains SIDs beyond the four expected accounts,"
        Write-Out "  flag for an IT professional to investigate."
    } else {
        Write-Out "  SeImpersonatePrivilege not explicitly set (system defaults -- normal)."
    }
} catch {
    Write-Out "  [ERROR] Could not export security policy: $_"
} finally {
    if (Test-Path $tmpInf) { Remove-Item $tmpInf -Force }
}

# -- 11. Network Connection Profiles --------------------------------------
Write-Section "11. NETWORK CONNECTION PROFILES"
Write-Out "Network should be set to 'Private' for a trusted shop LAN, not 'Public'."
Write-Out ""
try {
    $netProfiles = Get-NetConnectionProfile -ErrorAction Stop
    Write-Out ($netProfiles | Format-Table Name, NetworkCategory, IPv4Connectivity, IPv6Connectivity -AutoSize | Out-String)
} catch {
    Write-Out "  [ERROR] Could not retrieve network profiles: $_"
}

# -- Footer ---------------------------------------------------------------
$sep    = '-' * 60
$footer = "`n$sep`nCapture complete. File saved to:`n$outputFile`n$sep"
$footer | Out-File -FilePath $outputFile -Append -Encoding UTF8
Write-Host $footer -ForegroundColor Green
