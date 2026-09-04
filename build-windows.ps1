[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Iso,

    [string]$OutputIso = (Join-Path (Get-Location) "Windows10-Gaming.iso"),

    [ValidateRange(1, 99)]
    [int]$EditionIndex = 1
)

$ErrorActionPreference = "Stop"

function Invoke-DeploymentCommand {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Executable,

        [Parameter(Mandatory = $true)]
        [string[]]$Arguments
    )

    & $Executable @Arguments

    if ($LASTEXITCODE -ne 0) {
        throw "$Executable failed with exit code $LASTEXITCODE."
    }
}

$currentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
$currentPrincipal = [Security.Principal.WindowsPrincipal]::new($currentIdentity)
$administratorRole = [Security.Principal.WindowsBuiltInRole]::Administrator

if (-not $currentPrincipal.IsInRole($administratorRole)) {
    throw "Run this builder from an elevated PowerShell session."
}

$sourceIsoPath = [IO.Path]::GetFullPath((Resolve-Path -LiteralPath $Iso).Path)
$outputIsoPath = [IO.Path]::GetFullPath($OutputIso)

if ($sourceIsoPath -ieq $outputIsoPath) {
    throw "The output ISO must differ from the source ISO."
}

if (Test-Path -LiteralPath $outputIsoPath) {
    throw "The output ISO already exists. Refusing to overwrite it."
}

$deploymentTools = @("dism.exe", "oscdimg.exe")
foreach ($deploymentTool in $deploymentTools) {
    if ($null -eq (Get-Command -Name $deploymentTool -ErrorAction SilentlyContinue)) {
        throw "$deploymentTool was not found. Install Windows ADK Deployment Tools."
    }
}

$temporaryRoot = Join-Path $env:TEMP ("win10-gaming-" + [Guid]::NewGuid().ToString("N"))
$mediaPath = Join-Path $temporaryRoot "media"
$mountPath = Join-Path $temporaryRoot "mount"
$optimizedWimPath = Join-Path $temporaryRoot "install-optimized.wim"
$mountedDiskImage = $false
$mountedWim = $false

$optionalAppNames = @(
    "Microsoft.3DBuilder",
    "Microsoft.Microsoft3DViewer",
    "Microsoft.BingWeather",
    "Microsoft.GetHelp",
    "Microsoft.Getstarted",
    "Microsoft.MicrosoftOfficeHub",
    "Microsoft.MicrosoftSolitaireCollection",
    "Microsoft.People",
    "Microsoft.SkypeApp",
    "Microsoft.WindowsFeedbackHub",
    "Microsoft.WindowsMaps",
    "Microsoft.YourPhone",
    "Microsoft.ZuneMusic",
    "Microsoft.ZuneVideo",
    "Microsoft.MixedReality.Portal",
    "Microsoft.549981C3F5F10"
)

try {
    New-Item -Path $mediaPath, $mountPath -ItemType Directory -Force | Out-Null

    Write-Host "[1/8] Mounting source ISO"
    $diskImage = Mount-DiskImage -ImagePath $sourceIsoPath -PassThru
    $mountedDiskImage = $true
    $volume = $diskImage | Get-DiskImage | Get-Disk | Get-Partition | Get-Volume |
        Where-Object DriveLetter

    if ($null -eq $volume) {
        throw "The source ISO has no accessible volume."
    }

    $sourceRoot = "$($volume.DriveLetter):\"

    Write-Host "[2/8] Copying installation media"
    & robocopy.exe $sourceRoot $mediaPath /E /COPY:DAT /DCOPY:DAT /R:2 /W:2 /NFL /NDL /NP

    if ($LASTEXITCODE -ge 8) {
        throw "robocopy failed with exit code $LASTEXITCODE."
    }

    Dismount-DiskImage -ImagePath $sourceIsoPath
    $mountedDiskImage = $false

    $installWimPath = Join-Path $mediaPath "sources\install.wim"
    if (-not (Test-Path -LiteralPath $installWimPath)) {
        throw "The source ISO does not contain sources\install.wim. Convert install.esd separately first."
    }

    Write-Host "[3/8] Mounting install.wim index $EditionIndex"
    Invoke-DeploymentCommand "dism.exe" @(
        "/Mount-Wim",
        "/WimFile:$installWimPath",
        "/Index:$EditionIndex",
        "/MountDir:$mountPath"
    )
    $mountedWim = $true

    Write-Host "[4/8] Removing selected provisioned apps offline"
    $provisionedPackages = Get-AppxProvisionedPackage -Path $mountPath
    foreach ($appName in $optionalAppNames) {
        $matchingPackages = $provisionedPackages | Where-Object DisplayName -eq $appName

        foreach ($package in $matchingPackages) {
            Write-Host "Removing package: $($package.DisplayName)"
            Remove-AppxProvisionedPackage -Path $mountPath -PackageName $package.PackageName
        }
    }

    Write-Host "[5/8] Committing offline image"
    Invoke-DeploymentCommand "dism.exe" @(
        "/Unmount-Wim",
        "/MountDir:$mountPath",
        "/Commit"
    )
    $mountedWim = $false

    Write-Host "[6/8] Recompressing install.wim"
    Invoke-DeploymentCommand "dism.exe" @(
        "/Export-Image",
        "/SourceImageFile:$installWimPath",
        "/SourceIndex:1",
        "/DestinationImageFile:$optimizedWimPath",
        "/Compress:max",
        "/CheckIntegrity"
    )
    Copy-Item -LiteralPath $optimizedWimPath -Destination $installWimPath -Force

    Write-Host "[7/8] Adding first-logon configuration"
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot "autounattend.xml") -Destination $mediaPath -Force
    $oemSourcePath = Join-Path $PSScriptRoot 'oem\$OEM$\$1\GamingSetup'
    $oemTargetPath = Join-Path $mediaPath 'sources\$OEM$\$1\GamingSetup'
    New-Item -Path $oemTargetPath -ItemType Directory -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $oemSourcePath "debloat.ps1") -Destination $oemTargetPath -Force

    Write-Host "[8/8] Building bootable ISO"
    $biosBootFile = Join-Path $mediaPath "boot\etfsboot.com"
    $uefiBootFile = Join-Path $mediaPath "efi\microsoft\boot\efisys.bin"
    $bootData = '-bootdata:2#p0,e,b"{0}"#pEF,e,b"{1}"' -f $biosBootFile, $uefiBootFile
    Invoke-DeploymentCommand "oscdimg.exe" @(
        "-m",
        "-o",
        "-u2",
        "-udfver102",
        $bootData,
        $mediaPath,
        $outputIsoPath
    )

    Write-Host "ISO created successfully."
}
finally {
    if ($mountedWim) {
        & dism.exe "/Unmount-Wim" "/MountDir:$mountPath" "/Discard" | Out-Null
    }

    if ($mountedDiskImage) {
        Dismount-DiskImage -ImagePath $sourceIsoPath -ErrorAction SilentlyContinue
    }

    if (Test-Path -LiteralPath $temporaryRoot) {
        Remove-Item -LiteralPath $temporaryRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}
