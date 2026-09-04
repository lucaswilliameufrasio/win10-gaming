# Windows 10 Gaming ISO

This repository provides two conservative ways to customize an official
Windows 10 ISO. It does not include Microsoft installation media or activation
material.

## Repository layout

```text
win10-gaming/
├── autounattend.xml
├── build.sh
├── build-windows.ps1
├── scripts/
│   └── debloat.ps1
└── oem/
    └── $OEM$/$1/GamingSetup/debloat.ps1
```

The PowerShell file is kept in both locations intentionally: `scripts/` is the
source file for review, and the `$OEM$` copy is the file Windows Setup places
at `C:\GamingSetup\debloat.ps1`.

## What it changes

- Removes a small, explicit list of optional provisioned apps.
- Disables selected non-essential services such as telemetry, maps, fax and
  remote registry.
- Disables Windows consumer suggestions through policy.
- Requests the minimum telemetry level supported by the installed edition.

It intentionally leaves Windows Update, Defender, Firewall, networking,
Bluetooth, printing, audio, webcam, Store, Xbox, Game Pass and gaming
services untouched.

## Build on Linux or macOS

Install `xorriso` using the package manager for the build host. The builder is
provided for later use on a compatible host; do not run it against an unknown
or untrusted ISO.

```sh
./build.sh /path/to/official-windows-10.iso /path/to/Windows10-Gaming.iso
```

The command must be run manually. It refuses to overwrite an existing output
file, keeps the original `install.wim`, and replays the source ISO boot data.
The resulting ISO still performs the regular interactive Windows setup. The
PowerShell configuration runs once at the first user logon.

## Build on Windows

For a physically smaller ISO, run `build-windows.ps1` from an elevated PowerShell
session on Windows with the Windows ADK `Deployment Tools` installed. This mode
mounts one selected `install.wim` edition, removes the explicit optional AppX
list offline, recompresses the WIM and rebuilds the BIOS/UEFI bootable ISO.

Requirements:

- A Windows 10/11 build host running PowerShell as Administrator.
- Windows ADK with only `Deployment Tools` selected.
- An official ISO containing `sources\install.wim`.
- A destination folder with enough free space for the temporary mounted image
  and the generated ISO.

To inspect the available editions before choosing an index:

```powershell
dism /Get-WimInfo /WimFile:D:\Downloads\Windows10\sources\install.wim
```

The input ISO must first be mounted or extracted so the `install.wim` index can
be inspected. The builder itself mounts the ISO, copies its contents, services
the selected index, and creates the output ISO.

```powershell
.\build-windows.ps1 -Iso "D:\Downloads\Windows10.iso" -OutputIso "D:\Build\Windows10-Gaming.iso" -EditionIndex 1
```

The default edition index is `1`. Confirm the correct index for the official ISO
before building. The Windows builder currently requires `sources\install.wim`;
ISOs containing only `install.esd` must be converted separately with DISM.

The builder does not automate disk partitioning, account creation, passwords,
product keys or activation. It refuses to overwrite an existing output ISO and
cleans its temporary working directory after completion or failure.

## Important limitations

The Linux/macOS method does not physically shrink the WIM or remove packages
offline. Use the Windows builder when that behavior is required.

Review the app and service lists before using the ISO on production hardware.
Keep the official ISO and a normal Windows installation path available.

## Continuous integration

GitHub Actions validates every push and pull request with:

- ShellCheck for `build.sh`.
- XML parsing for `autounattend.xml`.
- PSScriptAnalyzer for both PowerShell builders.
- A consistency check for the embedded `$OEM$` PowerShell copy.
- Git whitespace validation.

CI performs static validation only. It never builds a Windows ISO, mounts a
WIM, changes a Windows installation or handles secrets.

## Safety boundaries

- Do not commit ISO files, install images, logs, credentials or activation
  material.
- Do not add passwords, product keys, personal paths or account automation to
  `autounattend.xml`.
- This repository was prepared without executing the build or PowerShell
  scripts on macOS.
