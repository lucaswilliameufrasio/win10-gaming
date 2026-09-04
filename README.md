# Windows 10 Gaming ISO

This repository adds a conservative post-install configuration to an official
Windows 10 ISO. It does not include Microsoft installation media and does not
modify `install.wim`.

## Repository layout

```text
win10-gaming/
├── autounattend.xml
├── build.sh
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

## Important limitations

This method does not physically shrink the WIM or remove packages offline.
Offline servicing requires a Windows host with Microsoft Deployment Tools and
should be implemented separately if a smaller ISO is required.

Review the app and service lists before using the ISO on production hardware.
Keep the official ISO and a normal Windows installation path available.

## Safety boundaries

- Do not commit ISO files, install images, logs, credentials or activation
  material.
- Do not add passwords, product keys, personal paths or account automation to
  `autounattend.xml`.
- This repository was prepared without executing the build or PowerShell
  scripts on macOS.
