# Universal Package Manager (upm)
# Usage: upm.ps1 <action> <package(s)>
# Actions: install, remove, update, upgrade, search

# Import configuration
$configPath = Join-Path $PSScriptRoot "upm-config.psd1"
$config = Import-PowerShellDataFile -Path $configPath

function Show-Help {
    Write-Host "Windows Universal Package Manager (upm)"
    Write-Host "Usage: upm.ps1 <action> [package(s)] [-q] [-y]"
    Write-Host "Actions:"
    Write-Host "  install <package(s)>  - Install one or more packages"
    Write-Host "  remove <package(s)>   - Remove one or more packages"
    Write-Host "  update <package(s)>   - Update one or more specific packages"
    Write-Host "  upgrade               - Upgrade all packages"
    Write-Host "  search <package>      - Search for a package"
    exit
}

function Check-Version {
    $currentVersionFile = "C:\Windows\System32\upm-version"
    $remoteVersionUrl = "https://raw.githubusercontent.com/sctech-tr/upm/main/upm-version"

    # Check if version file exists
    if (-not (Test-Path $currentVersionFile)) {
        Write-Error "Error: Current version file not found."
        exit 1
    }

    # Read the current version
    $currentVersion = Get-Content $currentVersionFile

    # Fetch the remote version
    try {
        $remoteVersion = Invoke-RestMethod -Uri $remoteVersionUrl
    } catch {
        Write-Error "Error: Failed to fetch remote version."
        exit 1
    }

    # Compare versions
    if ($currentVersion -ne $remoteVersion) {
        Write-Host "upm $remoteVersion is available! You are currently on version $currentVersion."
        exit 0
    }
}

function Detect-PackageManager {
    foreach ($pm in $config.Keys) {
        if (Get-Command $config[$pm].Command -ErrorAction SilentlyContinue) {
            return $pm
        }
    }
    return $null
}

function Run-Command {
    param (
        [string]$PackageManager,
        [string]$Action,
        [string[]]$Packages,
    )

    $pmConfig = $config[$PackageManager]
    $cmdTemplate = $pmConfig.Actions[$Action]

    if (-not $cmdTemplate) {
        Write-Error "Error: Invalid action for $PackageManager."
        exit 1
    }

    foreach ($Package in $Packages) {
        $cmd = $cmdTemplate -replace '\$package', $Package
        $cmd = "$($pmConfig.Command) $cmd $quietFlag $yesFlag"

        Write-Host "Executing: $cmd"
        Invoke-Expression $cmd
    }
}

# Parse command line arguments
param(
    [Parameter(Position=0, Mandatory=$true)]
    [ValidateSet("install", "remove", "update", "upgrade", "search")]
    [string]$Action,

    [Parameter(Position=1)]
    [string[]]$Packages,
)

# Version check
Check-Version

if (-not $Action) {
    Show-Help
}

if ($Action -ne "upgrade" -and -not $Packages) {
    Write-Error "Error: Package name is required for $Action action."
    exit 1
}

$pm = Detect-PackageManager
if (-not $pm) {
    Write-Error "Error: No supported package manager detected."
    exit 1
}

Run-Command -PackageManager $pm -Action $Action -Packages $Packages
