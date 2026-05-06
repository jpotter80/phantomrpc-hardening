# 02_services.ps1
# PhantomRPC Hardening -- Ensure RPC-Critical Services Are Running
# Sets DHCP Client and Windows Time to Automatic start and starts them if stopped.
# These services are expected on any standard Windows machine and are safe to enable.

#Requires -RunAsAdministrator

Write-Host "`n[*] PhantomRPC service hardening -- starting..." -ForegroundColor Cyan

$services = @(
    @{ Name = 'Dhcp';    Label = 'DHCP Client'  },
    @{ Name = 'W32Time'; Label = 'Windows Time' }
)

foreach ($svc in $services) {
    Write-Host "`n[*] Checking: $($svc.Label) ($($svc.Name))"
    try {
        $s = Get-Service -Name $svc.Name -ErrorAction Stop

        if ($s.StartType -ne 'Automatic') {
            Set-Service -Name $svc.Name -StartupType Automatic
            Write-Host "    [+] StartType set to Automatic (was: $($s.StartType))"
        } else {
            Write-Host "    [+] StartType already Automatic -- no change needed"
        }

        if ($s.Status -ne 'Running') {
            Start-Service -Name $svc.Name -ErrorAction Stop
            Write-Host "    [+] Service started"
        } else {
            Write-Host "    [+] Service already running -- no change needed"
        }

    } catch {
        Write-Host "    [ERROR] Could not configure $($svc.Label): $_" -ForegroundColor Red
    }
}

Write-Host "`n[+] Service check complete." -ForegroundColor Green

# Confirm final state
Write-Host "`n[*] Final service state:"
@('Dhcp','W32Time') | ForEach-Object {
    Get-Service -Name $_ | Format-Table Name, DisplayName, Status, StartType -AutoSize
}