# backup configuration
$ExeName = "restic.exe"
$InstallPath = "C:\restic"
$ResticExe = Join-Path $InstallPath $ExeName
$StateFile = Join-Path $InstallPath "state.xml"
$WindowsExcludeFile = Join-Path $InstallPath "windows.exclude"
$LocalExcludeFile = Join-Path $InstallPath "local.exclude"
$LogPath = Join-Path $InstallPath "logs"
$LogRetentionDays = 30
$InternetTestAttempts = 10
$GlobalRetryAttempts = 4
$IgnoreMissingBackupSources = $false

# maintenance configuration
$SnapshotMaintenanceEnabled = $true
$SnapshotRetentionPolicy = @("--group-by", "host,tags", "--keep-daily", "30", "--keep-weekly", "52", "--keep-monthly", "24", "--keep-yearly", "10")
$SnapshotPrunePolicy = @("--max-unused", "1%")
$SnapshotMaintenanceInterval = 7
$SnapshotMaintenanceDays = 30
$SnapshotDeepMaintenanceDays = 90;

# email configuration
$SendEmailOnSuccess = $false
$SendEmailOnError = $true

# healthchecks.io configuration
$SendHealthcheck = $false
$healthcheckURL = "<healthchecks.io URL>"

# Paths to backup
$BackupSources = @{}
$BackupSources["C:\"] = @(
#    'Users'
)
#$BackupSources["D:\"] = @(
#    'Software'
#)
#$BackupSources["DRIVE_LABEL_NAME_OR_SERIAL_NUMBER"] = @(
#    'FolderName'
#)
