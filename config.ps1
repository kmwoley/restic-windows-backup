# general configuration
$InstallPath = "C:\restic"
$ExeName = "restic.exe"
$GlobalParameters = @()
$LogRetentionDays = 30
$BackupOnMeteredNetwork = $true
$InternetTestAttempts = 10
$GlobalRetryAttempts = 4

# email configuration
$SendEmailOnSuccess = $false
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

# (optional) custom actions 
# Define commands to pass to Invoke-Expression at script start and end
# note: Errors will only be reported if the script does not eventually succeed. Errors 
#       from unsuccessful attempts to backup or maintain the repository will not result
#       in the custom error action being called unless all attempts failed. 
$CustomActionStart = $null
$CustomActionEndError = $null
$CustomActionEndSuccess = $null