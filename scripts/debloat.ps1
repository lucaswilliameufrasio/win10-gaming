$ErrorActionPreference = "Continue"

$currentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
$currentPrincipal = [Security.Principal.WindowsPrincipal]::new($currentIdentity)
$administratorRole = [Security.Principal.WindowsBuiltInRole]::Administrator

if (-not $currentPrincipal.IsInRole($administratorRole)) {
    Write-Warning "Administrator privileges are required. No changes were made."
    exit 1
}

Write-Host "Windows 10 Gaming configuration started."

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

foreach ($appName in $optionalAppNames) {
    Write-Host "Removing optional app: $appName"

    Get-AppxProvisionedPackage -Online |
        Where-Object DisplayName -eq $appName |
        Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue

    Get-AppxPackage -AllUsers -Name $appName |
        Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue
}

$nonEssentialServiceNames = @(
    "DiagTrack",
    "dmwappushservice",
    "MapsBroker",
    "RemoteRegistry",
    "RetailDemo",
    "WMPNetworkSvc",
    "Fax",
    "PhoneSvc"
)

foreach ($serviceName in $nonEssentialServiceNames) {
    $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue

    if ($null -ne $service) {
        Write-Host "Disabling optional service: $serviceName"
        Stop-Service -Name $serviceName -Force -ErrorAction SilentlyContinue
        Set-Service -Name $serviceName -StartupType Disabled -ErrorAction SilentlyContinue
    }
}

$cloudContentPolicyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent"
New-Item -Path $cloudContentPolicyPath -Force | Out-Null
Set-ItemProperty `
    -Path $cloudContentPolicyPath `
    -Name "DisableWindowsConsumerFeatures" `
    -Type DWord `
    -Value 1

$dataCollectionPolicyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection"
New-Item -Path $dataCollectionPolicyPath -Force | Out-Null
Set-ItemProperty `
    -Path $dataCollectionPolicyPath `
    -Name "AllowTelemetry" `
    -Type DWord `
    -Value 0

Write-Host "Windows 10 Gaming configuration completed."
