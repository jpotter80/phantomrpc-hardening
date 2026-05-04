# PhantomRPC Hardening — Small Business Remediation

## Background

PhantomRPC is a Windows privilege escalation vulnerability disclosed by Kaspersky
researcher Haidar Kabibo on April 24, 2026 (presented at Black Hat Asia 2026).
Microsoft reviewed the report, declined to assign a CVE, and closed the case
without issuing a patch. It affects all currently-supported versions of Windows
(10, 11, Server 2019/2022/2025).

**What it does in plain English:** Windows uses a system called RPC (Remote
Procedure Call) so programs can talk to each other internally. PhantomRPC
exploits the fact that Windows does not verify a service is the *legitimate* one
before connecting to it. If a real Windows service is stopped or disabled, any
other program can impersonate it and intercept the connection — borrowing the
identity of whatever called it, often SYSTEM (the most powerful account on the
machine). This allows a low-privileged attacker who has already landed on the
machine (via phishing, a malicious download, etc.) to elevate themselves to full
administrator.

**Who is at risk:** This is a *local* privilege escalation — an attacker must
already be running code on the machine. It is not a remote break-in exploit by
itself. The realistic threat for a small retail business is a ransomware chain:
phishing email → low-privilege foothold → PhantomRPC escalation → full machine
compromise, file encryption, or data theft.

---

## What Was Done on This Machine

The following scripts were run in this repository. Each script writes its
findings to the `output/` directory.

### 00_capture.ps1 — System Inventory (Read-Only)

Collects a comprehensive snapshot of the machine without making any changes.
Output: `output/capture-<COMPUTERNAME>-<DATE>.txt`

Captures:
- Windows edition, version, and build number
- Installed hotfixes (last 30), confirming patch currency
- Status of the four services most relevant to PhantomRPC:
  `TermService` (Remote Desktop), `Dhcp`, `W32Time`, `WdiSystemHost`
- All currently running services
- Microsoft Defender status (real-time protection, tamper protection,
  signature currency, engine version)
- Windows Firewall state across all three profiles (Domain, Private, Public)
- All TCP ports currently listening (network exposure)
- Members of the local Administrators group
- Accounts holding `SeImpersonatePrivilege` (the privilege PhantomRPC abuses)
- Current network profile category (Private vs. Public)

### 01_windows_update.ps1 — Install Pending Updates

Ensures Windows Update is enabled and installs all available updates.
May trigger an automatic reboot if required by a patch.

What it does:
- Sets the Windows Update service (`wuauserv`) to Automatic start
- Installs the `PSWindowsUpdate` PowerShell module if not already present
- Downloads and installs all available Windows updates
- Reboots automatically if any update requires it

Why it matters: PhantomRPC itself has no patch, but every *other*
vulnerability an attacker might chain with it needs to be closed. Keeping
Windows fully patched is the single highest-impact action available.

### 02_services.ps1 — Ensure RPC-Critical Services Are Running

Sets `Dhcp` (DHCP Client) and `W32Time` (Windows Time) to start automatically
and starts them if stopped.

Why it matters: PhantomRPC works by squatting on the RPC address of a stopped
service. If the legitimate service is running, its endpoint is occupied and
cannot be hijacked. DHCP and W32Time are safe to enable on any Windows machine
and are expected to be running by default.

### 03_defender_check.ps1 — Microsoft Defender Verification (Read-Only)

Checks and reports the state of Microsoft Defender. Makes no changes.
Output: appended to the capture file, and printed to the console.

A future IT professional should act on any `[FAIL]` items in the output.

### 04_firewall_check.ps1 — Windows Firewall Verification (Read-Only)

Checks and reports whether the Windows Firewall is enabled on all profiles.
Makes no changes.

**If the firewall is reported as disabled:** Do not enable it without
understanding why it is off. Some point-of-sale systems, receipt printers,
or payment terminal software disable the firewall as part of their setup.
A future IT professional should investigate before re-enabling it.

---

## What Was Not Done (Recommended for Future IT Review)

The following mitigations from the full PhantomRPC remediation plan were
intentionally excluded to avoid disrupting existing shop operations:

- **SMBv1 disablement** — could affect older shared printers or devices
- **Remote Registry disablement** — may be required by some POS or remote
  support software
- **Windows Firewall rule additions** — requires mapping all shop network
  dependencies first
- **SeImpersonatePrivilege audit** — requires understanding all service accounts
  present on the machine
- **Network segmentation (VLANs)** — requires router/switch configuration
- **Attack Surface Reduction (ASR) rules** — requires testing against POS software
- **EDR/endpoint security upgrade** — procurement and configuration project
- **Non-admin daily user accounts** — requires workflow changes and staff training

A qualified IT professional should review the `output/capture-*.txt` files
from this engagement before proceeding with any of the above.

---

## Output Files

All output is written to the `output/` directory in this repository.
These files are excluded from git (see `.gitignore`) and remain only on the
local machine where the scripts were run. They contain sensitive system
information and should be treated accordingly.

---

## References

- Kaspersky Securelist report: https://securelist.com/phantomrpc-rpc-vulnerability/119428/
- Proof-of-concept and monitoring tools: https://github.com/klsecservices/PhantomRPC
- CISA Known Exploited Vulnerabilities: https://www.cisa.gov/known-exploited-vulnerabilities-catalog
