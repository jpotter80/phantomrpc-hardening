# On-Site Runbook — PhantomRPC Hardening
# Operator: James Potter

This document is your step-by-step guide for on-site execution.
Follow each section in order. Do not skip ahead.

---

## Prerequisites

These must be in place before you begin on the shop's Windows machine.

- [ ] Git is installed on the Windows machine
      Check: open PowerShell and run `git --version`
      If not installed: https://git-scm.com/download/win (use defaults)
- [ ] You have physical or remote access to the machine
- [ ] You can open PowerShell as Administrator
      How: click Start, type `PowerShell`, right-click → Run as administrator

---

## Step 1 — Clone the Repository

Open PowerShell as Administrator on the shop's Windows machine.
Run the following commands exactly as written.

```powershell
# Navigate to a working directory (C:\Temp is fine; create it if needed)
New-Item -ItemType Directory -Force -Path C:\Temp
cd C:\Temp

# Clone the repo
git clone https://github.com/jpotter80/phantomrpc-hardening.git

# Enter the repo directory
cd phantomrpc-hardening
```

The repo is now at `C:\Temp\phantomrpc-hardening`.
All output files will be saved to `C:\Temp\phantomrpc-hardening\output\`.

---

## Step 2 — Run the Capture Script

This script is read-only. It changes nothing on the machine.

```powershell
powershell -ExecutionPolicy Bypass -File scripts\00_capture.ps1
```

When it finishes it will print the path to the output file.
Open that file now — it will be in the `output\` folder.

```powershell
# Open the output file in Notepad
notepad output\(Get-ChildItem output\*.txt | Sort-Object LastWriteTime -Descending | Select-Object -First 1 -ExpandProperty Name)
```

Or simply open File Explorer, navigate to `C:\Temp\phantomrpc-hardening\output\`
and open the `.txt` file there.

---

## Step 3 — Decision Table

Work through each row using the output file from Step 2.
Run each applicable script, then move to the next row.
Scripts are safe to run in any order, but run 01 before 02 if both apply.

| # | What to look for in the output file | If the finding is BAD | If the finding is OK |
|---|---|---|---|
| 1 | **Windows Update Service** — look for `wuauserv` StartType | StartType is NOT `Automatic` → run `01_windows_update.ps1` | StartType is `Automatic` → check row 2 |
| 2 | **Patch currency** — look for the newest hotfix date under "Installed Hotfixes" | Newest patch is more than 30 days old → run `01_windows_update.ps1` | Patches are current → no action |
| 3 | **DHCP Client service** — look for `Dhcp` under "PhantomRPC-Relevant Services" | Status is `Stopped` OR StartType is NOT `Automatic` → run `02_services.ps1` | Status `Running`, StartType `Automatic` → no action |
| 4 | **Windows Time service** — look for `W32Time` under "PhantomRPC-Relevant Services" | Status is `Stopped` OR StartType is NOT `Automatic` → run `02_services.ps1` | Status `Running`, StartType `Automatic` → no action |
| 5 | **Microsoft Defender** — look for `[FAIL]` lines under "Defender Status" | Any `[FAIL]` present → **note for IT professional** (do not attempt to fix) | All `[PASS]` → no action |
| 6 | **Windows Firewall** — look for `[FAIL]` lines under "Firewall Status" | Any `[FAIL]` present → **note for IT professional** (do not enable — may affect POS/printer) | All `[PASS]` → no action |

---

## How to Run an Action Script

Replace `<script_name>` with the actual script filename (e.g., `01_windows_update.ps1`).

```powershell
powershell -ExecutionPolicy Bypass -File scripts\<script_name>
```

**Important — Windows Update reboot:** `01_windows_update.ps1` will
automatically reboot the machine if any update requires it. Save any open
work before running this script. After reboot, re-open PowerShell as
Administrator and navigate back:

```powershell
cd C:\Temp\phantomrpc-hardening
```

---

## Step 4 — Notes to Leave

After completing all applicable scripts, record the following in a
plain text file or on paper for the business owner and future IT professional:

- Machine name (shown at the top of the capture output)
- Windows version and build (shown in capture output)
- Date of visit
- Which scripts were run (from the decision table)
- Any `[FAIL]` items from rows 5 or 6 (Defender / Firewall)
- Any other observations

These notes, combined with the capture output file in `output\`, give a
future IT professional everything they need to continue from where you left off.

---

## Step 5 — Repeat for Each Machine

Return to Step 1 for each additional Windows PC in the shop.
Each machine gets its own capture file (named by computer name and date).

---

## Reference — Running the Scripts Manually

If you need to re-run any script outside the normal flow:

```powershell
# Capture (read-only, safe to run anytime)
powershell -ExecutionPolicy Bypass -File scripts\00_capture.ps1

# Windows Update (may reboot)
powershell -ExecutionPolicy Bypass -File scripts\01_windows_update.ps1

# Services (DHCP + W32Time)
powershell -ExecutionPolicy Bypass -File scripts\02_services.ps1

# Defender check (read-only)
powershell -ExecutionPolicy Bypass -File scripts\03_defender_check.ps1

# Firewall check (read-only)
powershell -ExecutionPolicy Bypass -File scripts\04_firewall_check.ps1
```
