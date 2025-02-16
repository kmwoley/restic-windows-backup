<#
.SYNOPSIS
    Updates the local installed restic backup scripts from GitHub,
    either using the latest tagged release or by targeting a specific branch.

.DESCRIPTION
    This script supports two modes:

    1. **Release mode (default):**
       - Fetches the latest release info via GitHub’s API.
       - Compares the release tag (after normalization) against a locally stored version (in version.txt).
       - If the GitHub release is newer, downloads the release zip, extracts it, copies the files
         over the local installation.

    2. **Branch mode:**
       - Targets a specific branch (default "main") by retrieving branch information from GitHub.
       - Compares the latest commit SHA on that branch against a locally stored SHA.
       - If the remote commit SHA differs, downloads the branch zip archive, extracts it,
         copies the files over the local installation.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [ValidateSet("release", "branch")]
    [string]$Mode = "release",

    [Parameter(Mandatory = $false)]
    [string]$BranchName = "main",

    [Parameter(Mandatory = $false)]
    [string]$InstallPath = $null
)

# ====================================
# Configuration and Setup
# ====================================

# GitHub repository details
$repoOwner = "kmwoley"
$repoName  = "restic-windows-backup"

# User-Agent header (GitHub requires this)
$headers = @{ "User-Agent" = "PowerShell" }

# default the installation directory to the location of the running script
if([string]::IsNullOrEmpty($InstallPath)) {
    $InstallPath = $PSScriptRoot 
}

# ====================================
# Functions for state management
# ====================================
function Get-State {
    if(Test-Path $Script:StateFile) {
        Import-Clixml $Script:StateFile | ForEach-Object{ Set-Variable -Scope Script $_.Name $_.Value }
    }
}
function Set-State {
    Get-Variable ResticState* | Export-Clixml $Script:StateFile
}

# ===========================================
# Functions for file management and download
# ===========================================
function Get-ModifiedFiles {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Source,

        [Parameter(Mandatory = $true)]
        [string]$Destination,

        [Parameter(Mandatory = $true)]
        [string]$DateTime
    )

    ## FIXME: IS THERE A BETTER WAY TO INIT A LIST?
    $modifiedFiles = New-Object System.Collections.Generic.List[System.Object]

    if(-not (Test-Path $Source)) {
        Write-Error "Source does not exist ($Source)"
        exit 1
    }
    if(-not (Test-Path $Destination)) {
        Write-Error "Destination does not exist ($Destination)"
        exit 1
    }

    $sourceFiles = Get-ChildItem $Source

    ForEach ($sourceFile in $sourceFiles) {
        # find if there's a corrosponding file in the destination
        $destFileName = Join-Path $Destination $sourceFile.Name
        if(Test-Path $destFileName) {
            $destFile = Get-ChildItem $destFileName
            if($destFile.LastWriteTime -gt $DateTime) {
                # destination file has been modified after $DateTime
                $modifiedFiles.Add($destFile.FullName)
            }
        }
    }
    return $modifiedFiles
}

function Update-InstalledScripts {
    param(
        [Parameter(Mandatory=$true)][string]$ZipUrl,
        [Parameter(Mandatory=$true)][string]$DestinationFolder
    )

    $timestamp = Get-Date -Format FileDateTime
    $tempExtractDir = Join-Path $env:TEMP ("restic-windows-backup." + $timestamp)
    $tempZipPath = Join-Path $env:TEMP ("restic-windows-backup." + $timestamp + ".zip")

    # test temp location, fail if in use
    if (Test-Path $tempExtractDir) {
        Write-Error "Temporary directory already exists: $tempExtractDir"
        exit 1
    }
    if (Test-Path $tempZipPath) {
        Write-Error "Temporary directory already exists: $tempZipPath"
        exit 1
    }

    # Create a temporary folder for extraction
    New-Item -ItemType Directory -Path $tempExtractDir | Out-Null

    Write-Host "Downloading from: $ZipUrl"
    try {
        Invoke-WebRequest -Uri $ZipUrl -OutFile $tempZipPath -Headers $headers
    } catch {
        Write-Error "Failed to download the file: $_"
        exit 1
    }

    try {
        Expand-Archive -LiteralPath $tempZipPath $tempExtractDir
    } catch {
        Write-Error "Error extracting zip file: $_"
        exit 1 
    }

    # Determine the actual folder containing the repository files.
    $extractedContent = Get-ChildItem -Path $tempExtractDir | Where-Object { $_.PSIsContainer }
    if ($extractedContent.Count -eq 1) {
        $extractedFolder = $extractedContent[0].FullName
    } else {
        $extractedFolder = $tempExtractDir
    }

    # Check to make sure not to overwrite modified files
    $installedDate = $Script:ResticStateInstalledDate
    if([string]::IsNullOrEmpty($installedDate)) {
        # unkown install date; setting the date
        $installedDate = [datetime]::MinValue
    }
    
    $modifiedFiles = Get-ModifiedFiles -Source $extractedFolder -Destination $DestinationFolder -DateTime $installedDate
    if($modifiedFiles) {
        if([string]::IsNullOrEmpty($Script:ResticStateInstalledDate)) {
            Write-Host "WARNING: The following files already exist in the target directory"
        }        
        else {
            Write-Host "WARNING: The following files have been modified since they were installed on $installedDate"
        }
        ForEach ($fileName in $modifiedFiles) {
            Write-Host " - " $fileName
        }
        
        # TODO: add a "-Force" parameter to skip this check/question
        Write-Host "Continuing will overwrite these files."
        Write-host "Do you want to continue?"
        $userInput = Read-Host "[Y] Yes  [N] No  (default is ""Y"")"
        if ($userInput -ieq 'n') {
            Write-Host "Operation cancelled."
            exit 0
        }
    }

    Write-Host "Updating files in installation directory ($DestinationFolder)..."
    try {
        # Recursively copy all content from the extracted folder to the local directory.
        Copy-Item -Path (Join-Path $extractedFolder "*") -Destination $DestinationFolder -Recurse -Force
    } catch {
        Write-Error "Error copying files: $_"
        exit 1
    }

    # Clean up temporary files
    Remove-Item $tempZipPath -Force
    Remove-Item $tempExtractDir -Recurse -Force
}

# ====================================
# Main
# ====================================

# load restic state
$Script:ResticStateInstalledVersion = $null
$Script:ResticStateInstalledBranchSHA = $null
$Script:ResticStateInstalledDate = $null
$Script:StateFile = Join-Path $InstallPath "state.xml"
Get-State

# ====================================
# Release mode
# ====================================

if ($Mode -eq "release") {

    # Read the version of the scripts installed
    $localVersion = $Script:ResticStateInstalledVersion
    if ([string]::IsNullOrEmpty($localVersion)) {
        # Write-Host "No version information stored locally."
        $localVersion = "0.0.0"
    }
  
    # Get the Latest Release Info from GitHub
    $releaseApiUrl = "https://api.github.com/repos/$repoOwner/$repoName/releases/latest"
    try {
        Write-Host "Checking GitHub for latest release of '$repoOwner/$repoName'..."
        $release = Invoke-RestMethod -Uri $releaseApiUrl -Headers $headers
    } catch {
        Write-Error "Error fetching release information from GitHub: $_"
        exit 1
    }

    $latestTagRaw = $release.tag_name
    $latestTag    = $latestTagRaw.Trim()
    # Write-Host "Latest GitHub release version: $latestTag"

    # Normalize versions (remove leading "v" if present)
    function Normalize-Version($versionString) {
        if ($versionString.StartsWith("v", [System.StringComparison]::InvariantCultureIgnoreCase)) {
            return $versionString.Substring(1)
        }
        return $versionString
    }
    $normalizedLocalVersion  = Normalize-Version $localVersion
    $normalizedLatestVersion = Normalize-Version $latestTag

    try {
        $localVersionObj  = [Version]$normalizedLocalVersion
        $latestVersionObj = [Version]$normalizedLatestVersion
    } catch {
        Write-Error "Error parsing version strings. Local: $normalizedLocalVersion, Latest: $normalizedLatestVersion. $_"
        exit 1
    }

    if ($latestVersionObj -le $localVersionObj) {
        Write-Host "Installed version ($localVersionObj) is up-to-date. No update needed."
        exit 0
    } else {
        Write-Host "Newer release available: $latestVersionObj (installed: $localVersionObj). Proceeding with update..."
    }

    # get the zip URL from the release info
    $zipUrl = $release.zipball_url

    # Download and update the installed scripts
    Update-InstalledScripts -ZipUrl $zipUrl -DestinationFolder $InstallPath

    # Store the installed version number and time installed
    $Script:ResticStateInstalledVersion = $normalizedLatestVersion
    $Script:ResticStateInstalledDate = Get-Date
    $Script:ResticStateInstalledBranchSHA = $null
    Set-State

    Write-Host "Update successful. Installed version is now $normalizedLatestVersion."
}
# ====================================
# Branch mode
# ====================================
elseif ($Mode -eq "branch") {

    # Read the SHA of the branch source installed
    $localCommitSHA = $Script:ResticStateInstalledBranchSHA
    if ([string]::IsNullOrEmpty($localCommitSHA)) {
        # Write-Host "No branch information stored locally."
        $localCommitSHA = "unknown"
    }

    # Retrieve branch information from GitHub
    $branchApiUrl = "https://api.github.com/repos/$repoOwner/$repoName/branches/$BranchName"
    try {
        Write-Host "Checking GitHub for latest commit of '$repoOwner/$repoName' on branch '$BranchName'..."
        $branchInfo = Invoke-RestMethod -Uri $branchApiUrl -Headers $headers
    } catch {
        Write-Error "Error fetching branch information from GitHub: $_"
        exit 1
    }

    $latestCommitSHA = $branchInfo.commit.sha
    # Write-Host "Latest commit on $repoOwner/$repoName branch '$BranchName': $latestCommitSHA"

    if ($localCommitSHA -eq $latestCommitSHA) {
        Write-Host "Installed commit ($latestCommitSHA) is up-to-date. No update needed."
        exit 0
    } else {
        Write-Host "Latest commit: $latestCommitSHA (installed: $localCommitSHA). Proceeding with update..."
    }

    # Construct the zip URL for the branch.
    # GitHub provides branch archives at:
    # https://github.com/{owner}/{repo}/archive/refs/heads/{branch}.zip
    $zipUrl = "https://github.com/$repoOwner/$repoName/archive/refs/heads/$BranchName.zip"

    # Download and update the installed scripts
    Update-InstalledScripts -ZipUrl $zipUrl -DestinationFolder $InstallPath

    # Store the installed branch commit SHA and time installed
    $Script:ResticStateInstalledVersion = $null
    $Script:ResticStateInstalledDate = Get-Date
    $Script:ResticStateInstalledBranchSHA = $latestCommitSHA
    Set-State

    Write-Host "Update successful. Local branch is now at commit $latestCommitSHA."
}
else {
    Write-Error "Unsupported mode."
    exit 1
}
