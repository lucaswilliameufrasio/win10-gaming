# Improvement Guide

This document is the handoff guide for a person or an LLM improving this
project. It describes what to inspect, what to test, and what must not be
changed casually.

## Project model

The repository has two different build modes:

- `build.sh` runs on Linux or macOS and adds post-install configuration without
  servicing `install.wim`.
- `build-windows.ps1` runs on Windows with ADK Deployment Tools, services one
  selected `install.wim` index offline, recompresses it, and creates a bootable
  ISO.

Both modes add the same conservative `debloat.ps1`. The copy under
`oem/$OEM$/$1/GamingSetup/` must remain byte-for-byte identical to
`scripts/debloat.ps1`.

## Safety rules

Before changing anything:

1. Never read, print, commit, or upload secrets, product keys, tokens,
   activation data, personal paths, account names, or private ISO files.
2. Never run the builders or the PowerShell debloat script on macOS or Linux.
3. Never test against a real machine or a real user's installation first.
4. Use an official Windows ISO and keep its checksum and source documented
   without committing the ISO itself.
5. Refuse to overwrite input media, existing output ISOs, or mounted images.
6. Prefer an explicit allowlist over wildcard removal.
7. Do not remove a component just because its name contains `Telemetry`,
   `Xbox`, `Gaming`, or `Microsoft`.

## Recommended build lab

Use a Windows 10 Pro 22H2 x64 virtual machine as the build host:

- 8 virtual CPUs.
- 12 to 16 GB of RAM.
- At least 120 GB of free virtual disk space.
- UEFI enabled.
- Local administrator account, not a personal Microsoft account.
- Windows ADK with `Deployment Tools` installed.
- Snapshot taken before every build.

Use a second clean Windows VM as the installation test target. Take snapshots
before and after installation. Do not use the build VM as the only test target.

## Analysis workflow

### 1. Inventory the source ISO

On the Windows build VM, identify whether the ISO has `install.wim` or
`install.esd`, then list its editions and indexes. Do not assume index `1` is
the desired edition.

```powershell
dism /Get-WimInfo /WimFile:D:\Source\sources\install.wim
```

Record only non-sensitive metadata such as edition name, architecture, build
number, and image index.

### 2. Classify every removal candidate

Each candidate must be classified before being added to a removal list:

- AppX provisioned package: removable with `Get-AppxProvisionedPackage`.
- Installed Win32 application: needs a separate uninstall strategy.
- Windows capability: inspect with `Get-WindowsCapability` or DISM.
- Windows optional feature: inspect with `Get-WindowsOptionalFeature` or DISM.
- Service: disabling is not the same as uninstalling its owning component.
- Scheduled task or policy: changing it can affect diagnostics, updates, or
  recovery.

Examples that require separate handling:

- OneDrive is commonly a Win32 component, not a provisioned AppX package.
- Sticky Notes and OneNote package names vary by Windows release and edition.
- Windows Fax and Scan is associated with the `Fax.Scan` capability; disabling
  the `Fax` service does not remove the capability.

Do not add a candidate until its package, capability, feature, or service name
has been observed on the target Windows build.

### 3. Separate offline and post-install work

Offline work belongs in `build-windows.ps1` only when DISM supports it safely:

- Remove explicitly verified provisioned AppX packages.
- Remove explicitly verified optional capabilities or features.
- Export the selected image with integrity checking and maximum compression.

Post-install work belongs in `debloat.ps1`:

- Services and policies that must run in the installed operating system.
- Per-user cleanup that cannot be performed reliably offline.
- Win32 uninstallation only when an official, reversible uninstall command is
  known.

The script must report or preserve failures instead of silently claiming a
successful build. If an operation is intentionally best-effort, document why.

### 4. Review the essential-function matrix

After every removal change, test at least:

- Boot, sign-in, shutdown, sleep, and restart.
- Windows Update, Defender, Firewall, and recovery tools.
- Wi-Fi, Ethernet, Bluetooth, USB, audio, microphone, webcam, and printing.
- Microsoft Store, Xbox app, Gaming Services, Game Pass, Steam, and a test
  controller.
- Windows Search, Explorer, notifications, screenshots, and display drivers.
- DirectX games, anti-cheat software, and a game installed on a secondary disk.

The result must be recorded as pass, fail, or not applicable. A smaller ISO is
not an improvement if any essential function regresses.

## Implementation checklist

When changing the project:

- Keep package and service lists explicit and grouped by purpose.
- Preserve `install.wim` when using `build.sh`.
- Require `-EditionIndex` review when servicing a multi-edition WIM.
- Add support for `install.esd` only with a tested conversion/export path.
- Keep `SetupComplete.cmd` as the privileged primary path for machine-wide
  changes.
- Keep the fallback path idempotent and guarded by the completion marker.
- Keep `autounattend.xml` free of partitioning, passwords, product keys, and
  account automation.
- Update the source PowerShell file and its OEM copy together.
- Update this document and `README.md` whenever the behavior or requirements
  change.

## Validation checklist

Before pushing a change:

1. Inspect the complete diff and verify that no ISO, log, secret, or personal
   path is present.
2. Run ShellCheck on `build.sh`.
3. Parse `autounattend.xml` with an XML parser.
4. Run PSScriptAnalyzer on `build-windows.ps1` and `scripts/debloat.ps1`.
5. Compare both `debloat.ps1` copies byte-for-byte.
6. Run `git diff --check`.
7. Let GitHub Actions pass before using the script on Windows.
8. In the Windows lab, generate an ISO and install it in the clean test VM.
9. Verify both positive changes and the essential-function matrix.

Static CI validation is not a substitute for a Windows VM installation test.
The builders are intentionally not executed by CI because they require trusted
installation media, elevated privileges, large temporary storage, and a
Windows environment.

## Future improvements

Good next improvements, in order:

1. Add a read-only inventory mode that reports AppX packages, capabilities,
   optional features, services, and WIM indexes without changing anything.
2. Add explicit support for `install.esd` after testing conversion and index
   preservation.
3. Add a dry-run mode to `build-windows.ps1` that prints planned changes only.
4. Add machine-readable build metadata containing edition, architecture,
   source hash, and removed package names, but no personal paths or secrets.
5. Add a Windows VM smoke-test workflow on a self-hosted, isolated runner only
   after the security and licensing model is approved.

Any future removal list must include its observed package or capability name,
reason for removal, known dependencies, rollback path, and test results.
