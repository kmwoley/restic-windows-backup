# general configuration
$ExeName = "restic.exe"
$InstallPath = "C:\restic"
$ResticExe = Join-Path $InstallPath $ExeName
$StateFile = Join-Path $InstallPath "state.xml"
$LogPath = Join-Path $InstallPath "logs"
$LogRetentionDays = 30
$InternetTestAttempts = 10
$GlobalRetryAttempts = 4
$AdditionalParameters = @()

# email configuration
$SendEmailOnSuccess = $true
$SendEmailOnError = $true

# backup configuration
$WindowsExcludeFile = Join-Path $InstallPath "windows.exclude"
$LocalExcludeFile = Join-Path $InstallPath "local.exclude"
$IgnoreMissingBackupSources = $false
$AdditionalBackupParameters = @("--exclude-if-present", ".nobackup", "--no-scan")

# Paths to backup
$BackupSources = @{}
$BackupSources["C:\"] = @(
#    "Users\Example\Desktop\Source1",
#    "Users\Example\Desktop\Source2"
)
# $BackupSources["D:\"] = @(
#    "Example\Source3",
#    "Example\Source4"
# )
#$BackupSources["DRIVE_LABEL_NAME_OR_SERIAL_NUMBER"] = @(
#    "Example\FolderName"
#)

# maintenance configuration
$SnapshotMaintenanceEnabled = $true
$SnapshotRetentionPolicy = @("--host", $env:COMPUTERNAME, "--group-by", "host,tags", "--keep-daily", "30", "--keep-weekly", "52", "--keep-monthly", "24", "--keep-yearly", "10")
$SnapshotPrunePolicy = @("--max-unused", "1%")
$SnapshotMaintenanceInterval = 7
$SnapshotMaintenanceDays = 30
$SnapshotDeepMaintenanceDays = 90

# restic.exe self update configuration
$SelfUpdateEnabled = $true
$SelfUpdateParameters = @()