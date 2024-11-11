#
# Restic Windows Backup Script
#

# =========== start configuration =========== # 

# set restic configuration parmeters (destination, passwords, etc.)
$SecretsScript = Join-Path $PSScriptRoot "secrets.ps1"

# backup configuration variables
$ConfigScript = Join-Path $PSScriptRoot "config.ps1"

# =========== end configuration =========== #

# globals for state storage
$Script:ResticStateRepositoryInitialized = $null
$Script:ResticStateLastMaintenance = $null
$Script:ResticStateLastDeepMaintenance = $null
$Script:ResticStateMaintenanceCounter = $null
$Script:ResticStateLastBackupSuccessful = $true
$Script:ResticStateLastMaintenanceSuccessful = $true
 
# Returns all drive letters which exactly match the serial number, drive label, or drive name of 
# the input parameter. Returns all drives if no input parameter is provided.
# inspiration: https://stackoverflow.com/questions/31088930/combine-get-disk-info-and-logicaldisk-info-in-powershell
function Get-Drives {
    Param($ID)

    foreach($disk in Get-CimInstance Win32_Diskdrive) {
        $diskMetadata = Get-Disk | Where-Object { $_.Number -eq $disk.Index } | Select-Object -First 1
        $partitions = Get-CimAssociatedInstance -ResultClassName Win32_DiskPartition -InputObject $disk

        foreach($partition in $partitions) {

            $drives = Get-CimAssociatedInstance -ResultClassName Win32_LogicalDisk -InputObject $partition

            foreach($drive in $drives) {
                    
                $volume = Get-Volume |
                          Where-Object { $_.DriveLetter -eq $drive.DeviceID.Trim(":") } |
                          Select-Object -First 1

                if(($diskMetadata.SerialNumber.trim() -eq $ID) -or 
                    ($disk.Caption -eq $ID) -or
                    ($volume.FileSystemLabel  -eq $ID) -or
                    ($null -eq $ID)) {
    
                    [PSCustomObject] @{
                        DriveLetter   = $drive.DeviceID
                        Number        = $disk.Index
                        Label         = $volume.FileSystemLabel
                        Manufacturer  = $diskMetadata.Manufacturer
                        Model         = $diskMetadata.Model
                        SerialNumber  = $diskMetadata.SerialNumber.trim()
                        Name          = $disk.Caption
                        FileSystem    = $volume.FileSystem
                        PartitionKind = $diskMetadata.PartitionStyle
                        Drive         = $drive
                        Partition     = $partition
                        Disk          = $disk
                    }
                }
            }
        }
    }
}

# restore backup state from disk
function Get-BackupState {
    if(Test-Path $StateFile) {
        Import-Clixml $StateFile | ForEach-Object{ Set-Variable -Scope Script $_.Name $_.Value }
    }
}
function Set-BackupState {
    Get-Variable ResticState* | Export-Clixml $StateFile
}

# unlock the repository if need be
function Invoke-Unlock {
    Param($SuccessLog, $ErrorLog)

    $locks = & $ResticExe list locks --no-lock -q 3>&1 2>> $ErrorLog
    if($locks.Length -gt 0) {
        # unlock the repository (assumes this machine is the only one that will ever use it)
        & $ResticExe unlock 3>&1 2>> $ErrorLog | Out-File -Append $SuccessLog
        "[[Unlock]] Repository was locked. Unlocking." | Tee-Object -Append $ErrorLog | Out-File -Append $SuccessLog
        Start-Sleep 120 
    }
}

# test if maintenance on the backup set is needed. Return $true if maintenance is needed
function Test-Maintenance {
    Param($SuccessLog, $ErrorLog)

    # skip maintenance if disabled
    if($SnapshotMaintenanceEnabled -eq $false) {
        "[[Maintenance]] Skipping - maintenance disabled" | Out-File -Append $SuccessLog
        return $false
    }

    # skip maintenance if it's been done recently
    if(($null -ne $ResticStateLastMaintenance) -and ($null -ne $ResticStateMaintenanceCounter)) {
        $Script:ResticStateMaintenanceCounter += 1
        $delta = New-TimeSpan -Start $ResticStateLastMaintenance -End $(Get-Date)
        if(($delta.Days -lt $SnapshotMaintenanceDays) -and ($ResticStateMaintenanceCounter -lt $SnapshotMaintenanceInterval)) {
            "[[Maintenance]] Skipping - last maintenance $ResticStateLastMaintenance ($($delta.Days) days, $ResticStateMaintenanceCounter backups ago)" | Out-File -Append $SuccessLog
            return $false
        }
        else {
            "[[Maintenance]] Running - last maintenance $ResticStateLastMaintenance ($($delta.Days) days, $ResticStateMaintenanceCounter backups ago)" | Out-File -Append $SuccessLog
            return $true
        }
    }
    else {
        "[[Maintenance]] Running - no past maintenance history known." | Out-File -Append $SuccessLog        
        return $true
    }
}

# run maintenance on the backup set
function Invoke-Maintenance {
    Param($SuccessLog, $ErrorLog)
    
    "[[Maintenance]] Start $(Get-Date)" | Out-File -Append $SuccessLog
    $maintenance_success = $true
    Start-Sleep 120

    # forget snapshots based upon the retention policy
    "[[Maintenance]] Start forgetting..." | Out-File -Append $SuccessLog
    & $ResticExe forget $SnapshotRetentionPolicy 3>&1 2>> $ErrorLog | Out-File -Append $SuccessLog
    if(-not $?) {
        "[[Maintenance]] Forget operation completed with errors" | Tee-Object -Append $ErrorLog | Out-File -Append $SuccessLog
        $maintenance_success = $false
    }

    # prune (remove) data from the backup step. Running this separate from `forget` because
    #   `forget` only prunes when it detects removed snapshots upon invocation, not previously removed
    "[[Maintenance]] Start pruning..." | Out-File -Append $SuccessLog
    & $ResticExe prune $SnapshotPrunePolicy 3>&1 2>> $ErrorLog | Out-File -Append $SuccessLog
    if(-not $?) {
        "[[Maintenance]] Prune operation completed with errors" | Tee-Object -Append $ErrorLog | Out-File -Append $SuccessLog
        $maintenance_success = $false
    }

    # check data to ensure consistency
    "[[Maintenance]] Start checking..." | Out-File -Append $SuccessLog

    # check to determine if we want to do a full data check or not
    $data_check = @()
    if($null -ne $ResticStateLastDeepMaintenance) {
        $delta = New-TimeSpan -Start $ResticStateLastDeepMaintenance -End $(Get-Date)
        if(($null -ne $SnapshotDeepMaintenanceDays) -and ($delta.Days -ge $SnapshotDeepMaintenanceDays)) {
            "[[Maintenance]] Performing read data check. Last '--read-data' check ran $ResticStateLastDeepMaintenance ($($delta.Days) days ago)" | Out-File -Append $SuccessLog
            $data_check = @("--read-data")
            $Script:ResticStateLastDeepMaintenance = Get-Date
        }
        else {
            "[[Maintenance]] Performing fast check. Last '--read-data' check ran $ResticStateLastDeepMaintenance ($($delta.Days) days ago)" | Out-File -Append $SuccessLog
        }
    }
    else {
        # set the date, but don't do a deep check if we've never done a full data read
        $Script:ResticStateLastDeepMaintenance = Get-Date
    }

    & $ResticExe check @data_check 3>&1 2>> $ErrorLog | Out-File -Append $SuccessLog
    if(-not $?) {
        "[[Maintenance]] Check completed with errors" | Tee-Object -Append $ErrorLog | Out-File -Append $SuccessLog
        $maintenance_success = $false
    }

    # check for updated restic version
    "[[Maintenance]] Checking for new version of restic..." | Out-File -Append $SuccessLog
    & $ResticExe self-update 3>&1 2>> $ErrorLog | Out-File -Append $SuccessLog
    if(-not $?) {
        "[[Maintenance]] Self-update of restic.exe completed with errors" | Tee-Object -Append $ErrorLog | Out-File -Append $SuccessLog
        $maintenance_success = $false
    }

    "[[Maintenance]] End $(Get-Date)" | Out-File -Append $SuccessLog
    
    if($maintenance_success -eq $true) {
        $Script:ResticStateLastMaintenance = Get-Date
        $Script:ResticStateMaintenanceCounter = 0
    }

    return $maintenance_success
}

# Run restic backup 
function Invoke-Backup {
    Param($SuccessLog, $ErrorLog)

    "[[Backup]] Start $(Get-Date)" | Out-File -Append $SuccessLog
    $return_value = $true
    $starting_location = Get-Location
    ForEach ($item in $BackupSources.GetEnumerator()) {

        # Get the source drive letter or identifier and set as the root path
        $root_path = $item.Key
        $tag = $item.Key

        $vss_option = "--use-fs-snapshot"

        # Test if root path is a valid path, if not assume it is an external drive identifier
        if(-not (Test-Path $root_path)) {
            # attempt to find a drive letter associated with the identifier provided
            $drives = Get-Drives $root_path
            if($drives.Count -gt 1) {
                "[[Backup]] Fatal error - external drives with more than one partition are not currently supported." | Tee-Object -Append $SuccessLog | Out-File -Append $ErrorLog
                $return_value = $false
                continue
            }
            elseif ($drives.Count -eq 0) {
                $ignore_error = ($null -ne $IgnoreMissingBackupSources) -and $IgnoreMissingBackupSources
                $warning_message = "[[Backup]] Warning - backup path $root_path not found."
                if($ignore_error) {
                    $warning_message | Out-File -Append $SuccessLog                    
                }
                else {
                    $warning_message | Tee-Object -Append $SuccessLog | Out-File -Append $ErrorLog
                    $return_value = $false
                }
                continue
            }
            
            $root_path = Join-Path $drives[0].DriveLetter ""
            
            # disable VSS / file system snapshot for external drives
            # TODO: would be best to just test for VSS compatibility on the drive, rather than assume it won't work
            $vss_option = $null
        }

        "[[Backup]] Start $(Get-Date) [$tag]" | Out-File -Append $SuccessLog
        
        # build the list of folders to backup
        $folder_list = New-Object System.Collections.Generic.List[System.Object]
        if ($item.Value.Count -eq 0) {
            # backup everything in the root if no folders are provided
            $folder_list.Add($root_path)
        }
        else {
            # Build the list of folders from settings
            ForEach ($path in $item.Value) {
                $p = '"{0}"' -f ((Join-Path $root_path $path) -replace "\\$")
                
                if(Test-Path ($p -replace '"')) {
                    # add the folder if it exists
                    $folder_list.Add($p)
                }
                else {
                    # if the folder doesn't exist, log a warning/error
                    $ignore_error = ($null -ne $IgnoreMissingBackupSources) -and $IgnoreMissingBackupSources
                    $warning_message = "[[Backup]] Warning - backup path $p not found."
                    if($ignore_error) {
                        $warning_message | Out-File -Append $SuccessLog
                    }
                    else {
                        $warning_message | Tee-Object -Append $SuccessLog | Out-File -Append $ErrorLog
                        $return_value = $false
                    }
                }
            }

        }
        
        if(-not $folder_list) {
            # there are no folders to backup
            $ignore_error = ($null -ne $IgnoreMissingBackupSources) -and $IgnoreMissingBackupSources
            $warning_message = "[[Backup]] Warning - no folders to back up!"
            if($ignore_error) {
                $warning_message | Out-File -Append $SuccessLog
            }
            else {
                $warning_message | Tee-Object -Append $SuccessLog | Out-File -Append $ErrorLog
                $return_value = $false
            }
        }
        else {
            # Launch Restic
            & $ResticExe backup $folder_list $vss_option --tag "$tag" --exclude-file=$WindowsExcludeFile --exclude-file=$LocalExcludeFile $AdditionalBackupParameters 3>&1 2>> $ErrorLog | Out-File -Append $SuccessLog
            if(-not $?) {
                "[[Backup]] Completed with errors" | Tee-Object -Append $ErrorLog | Out-File -Append $SuccessLog
                $return_value = $false
            }
        }

        "[[Backup]] End $(Get-Date) [$tag]" | Out-File -Append $SuccessLog
    }
    
    Set-Location $starting_location
    "[[Backup]] End $(Get-Date)" | Out-File -Append $SuccessLog

    return $return_value
}

function Send-Email {
    Param($SuccessLog, $ErrorLog, $Action)

    # default the action string to "Backup"
    if($null -eq $Action) {
        $Action = "Backup"
    }

    $password = ConvertTo-SecureString $ResticEmailPassword -AsPlainText -Force
    $credentials = New-Object System.Management.Automation.PSCredential ($ResticEmailUsername, $password)

    $status = "SUCCESS"
    $past_failure = $false
    $body = ""
    if (($null -ne $SuccessLog) -and (Test-Path $SuccessLog) -and (Get-Item $SuccessLog).Length -gt 0) {
        $body = $(Get-Content -Raw $SuccessLog)

        # if previous run contained an error, send the success email confirming that the error has been resolved        
        if($Action -eq "Backup") {
            $past_failure = -not $Script:ResticStateLastBackupSuccessful
        }
        else {
            $past_failure = -not $Script:ResticStateLastMaintenanceSuccessful
        }
    }
    else {
        $body = "Crtical Error! Restic $Action log is empty or missing. Check log file path."
        $status = "ERROR"
    }
    $attachments = @{}
    if (($null -ne $ErrorLog) -and (Test-Path $ErrorLog) -and (Get-Item $ErrorLog).Length -gt 0) {
        $attachments = @{Attachments = $ErrorLog}
        $status = "ERROR"
    }
    if((($status -eq "SUCCESS") -and ($SendEmailOnSuccess -ne $false)) -or ((($status -eq "ERROR") -or $past_failure) -and ($SendEmailOnError -ne $false))) {
        $subject = "$env:COMPUTERNAME Restic $Action Report [$status]"

        # create a temporary error log to log errors; can't write to the same file that Send-MailMessage is reading
        $temp_error_log = $ErrorLog + "_temp"

        Send-MailMessage @ResticEmailConfig -From $ResticEmailFrom -To $ResticEmailTo -Credential $credentials -Subject $subject -Body $body @attachments 3>&1 2>> $temp_error_log

        if(-not $?) {
            "[[Email]] Sending email completed with errors" | Tee-Object -Append $temp_error_log | Out-File -Append $SuccessLog
        }

        # join error logs and remove the temporary
        Get-Content $temp_error_log | Add-Content $ErrorLog
        Remove-Item $temp_error_log
    }
}

function Invoke-ConnectivityCheck {
    Param($SuccessLog, $ErrorLog)
    
    if($InternetTestAttempts -le 0) {
        "[[Internet]] Internet connectivity check disabled. Skipping." | Out-File -Append $SuccessLog    
        return $true
    }

    # skip the internet connectivity check for local repos
    if(Test-Path $env:RESTIC_REPOSITORY) {
        "[[Internet]] Local repository. Skipping internet connectivity check." | Out-File -Append $SuccessLog    
        return $true
    }

    $repository_host = ''

    # use generic internet service for non-specific repo types (e.g. swift:, rclone:, etc. )
    if(($env:RESTIC_REPOSITORY -match "^swift:") -or 
        ($env:RESTIC_REPOSITORY -match "^rclone:")) {
        $repository_host = "cloudflare.com"
    }
    elseif($env:RESTIC_REPOSITORY -match "^b2:") {
        $repository_host = "api.backblazeb2.com"
    }
    elseif($env:RESTIC_REPOSITORY -match "^azure:") {
        $repository_host = "azure.microsoft.com"
    }
    elseif($env:RESTIC_REPOSITORY -match "^gs:") {
        $repository_host = "storage.googleapis.com"
    }
    else {
        # parse connection string for hostname
        # Uri parser doesn't handle leading connection type info (s3:, sftp:, rest:)
        $connection_string = $env:RESTIC_REPOSITORY -replace "^s3:" -replace "^sftp:" -replace "^rest:"
        if(-not ($connection_string -match "://")) {
            # Uri parser expects to have a protocol. Add 'https://' to make it parse correctly.
            $connection_string = "https://" + $connection_string
        }
        $repository_host = ([System.Uri]$connection_string).DnsSafeHost
    }

    if([string]::IsNullOrEmpty($repository_host)) {
        "[[Internet]] Repository string could not be parsed." | Tee-Object -Append $SuccessLog | Out-File -Append $ErrorLog
        return $false
    }

    # test for internet connectivity
    $connections = 0
    $sleep_count = $InternetTestAttempts
    while($true) {
        $connections = Get-NetRoute | Where-Object DestinationPrefix -eq '0.0.0.0/0' | Get-NetIPInterface | Where-Object ConnectionState -eq 'Connected' | Measure-Object | ForEach-Object{$_.Count}
        if($sleep_count -le 0) {
            "[[Internet]] Connection to repository ($repository_host) could not be established." | Tee-Object -Append $SuccessLog | Out-File -Append $ErrorLog
            return $false
        }
        if(($null -eq $connections) -or ($connections -eq 0)) {
            "[[Internet]] Waiting for internet connectivity... $sleep_count" | Out-File -Append $SuccessLog
            Start-Sleep 30
        }
        elseif(!(Test-Connection -ComputerName $repository_host -Quiet)) {
            "[[Internet]] Waiting for connection to repository ($repository_host)... $sleep_count" | Out-File -Append $SuccessLog
            Start-Sleep 30
        }
        else {
            return $true
        }
        $sleep_count--
    }
}

# check if on metered network
function Invoke-MeteredCheck {

    [void][Windows.Networking.Connectivity.NetworkInformation, Windows, ContentType = WindowsRuntime]
    
    $cost = [Windows.Networking.Connectivity.NetworkInformation]::GetInternetConnectionProfile().GetConnectionCost()
    $cost.ApproachingDataLimit -or $cost.OverDataLimit -or $cost.Roaming -or $cost.BackgroundDataUsageRestricted -or ($cost.NetworkCostType -ne "Unrestricted")
}

# check previous logs
function Invoke-HistoryCheck {
    Param($SuccessLog, $ErrorLog, $Action)

    # default the action to "Backup"
    if($null -eq $Action) {
        $Action = "Backup"
    }

    $filter = "*$Action.err.txt".ToLower()
    $logs = Get-ChildItem $LogPath -Filter $filter | ForEach-Object{$_.Length -gt 0}
    $logs_with_success = ($logs | Where-Object {($_ -eq $false)}).Count
    if($logs.Count -gt 0) {
        Write-Output "[[History]] $Action success rate: $logs_with_success / $($logs.Count) ($(($logs_with_success / $logs.Count).tostring("P")))" | Tee-Object -Append $SuccessLog
    }
}

# main function
function Invoke-Main {
    
    # check for elevation, required for creation of shadow copy (VSS)
    if (-not (New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))
    {
        Write-Error "[[Backup]] Elevation required (run as administrator). Exiting."
        exit 1
    }

    # initialize secrets
    . $SecretsScript
    
    # initialize config
    . $ConfigScript
    
    Get-BackupState

    if(!(Test-Path $LogPath)) {
        Write-Error "[[Backup]] Log file directory $LogPath does not exist. Exiting."
        Send-Email
        exit 1
    }

    $error_count = 0
    $backup_success = $false
    $maintenance_success = $false
    $maintenance_needed = $false

    $attempt_count = $GlobalRetryAttempts
    while ($attempt_count -gt 0) {
        # setup logfiles
        $timestamp = Get-Date -Format FileDateTime
        $success_log = Join-Path $LogPath ($timestamp + ".backup.log.txt")
        $error_log = Join-Path $LogPath ($timestamp + ".backup.err.txt")
        
        $repository_available = Invoke-ConnectivityCheck $success_log $error_log
        if($repository_available -eq $true) {
            $metered_network = Invoke-MeteredCheck
            if ($BackupOnMeteredNetwork -eq $true -or $metered_network -eq $false) {
                Invoke-Unlock $success_log $error_log
                $backup_success = Invoke-Backup $success_log $error_log

                # NOTE: a previously locked repository will cause errors in the log; but backup would be 'successful'
                # Removing this overly-aggressive test for backup success and relying upon Invoke-Backup to report on success/failure
                # $backup_success = ($backup_success -eq $true) -and (!(Test-Path $error_log) -or ((Get-Item $error_log).Length -eq 0))
                $total_attempts = $GlobalRetryAttempts - $attempt_count + 1
                if($backup_success -eq $true) {
                    # successful backup
                    Write-Output "[[Backup]] Succeeded after $total_attempts attempt(s)" | Tee-Object -Append $success_log

                    # test to see if maintenance is needed if the backup was successful
                    $maintenance_needed = Test-Maintenance $success_log $error_log
                }
                else {
                    Write-Output "[[Backup]] Ran with errors on attempt $total_attempts" | Tee-Object -Append $success_log | Tee-Object -Append $error_log
                    $error_count++
                }
            }
            else {
                Write-Output "[[Backup]] Failed - currently on metered connection." | Tee-Object -Append $success_log | Tee-Object -Append $error_log
                $error_count++
            }
        }
        else {
            Write-Output "[[Backup]] Failed - cannot access repository." | Tee-Object -Append $success_log | Tee-Object -Append $error_log
            $error_count++
        }

        $attempt_count--
        
        # update logs prior to sending email
        if($backup_success -eq $false) { 
            if($attempt_count -gt 0) {
                Write-Output "[[Backup]] Sleeping for 15 min and then retrying..." | Tee-Object -Append $success_log
            }
            else {
                Write-Output "[[Backup]] Retry limit has been reached. No more attempts to backup will be made." | Tee-Object -Append $success_log
            }
        }

        Invoke-HistoryCheck $success_log $error_log "Backup"
        Send-Email $success_log $error_log "Backup"

        # update the state of the last backup success or failure
        $Script:ResticStateLastBackupSuccessful = $backup_success
        
        # Save state to file
        Set-BackupState

        # loop exit/wait condition
        if(($backup_success -eq $false) -and ($attempt_count -gt 0)) {
            Start-Sleep (15*60)
        }
        else {
            break
        }
    } 

    # only run maintenance if the backup was successful and maintenance is needed
    $attempt_count = $GlobalRetryAttempts
    while (($maintenance_needed -eq $true) -and ($attempt_count -gt 0)) {
        # setup logfiles
        $timestamp = Get-Date -Format FileDateTime
        $success_log = Join-Path $LogPath ($timestamp + ".maintenance.log.txt")
        $error_log = Join-Path $LogPath ($timestamp + ".maintenance.err.txt")
        
        $repository_available = Invoke-ConnectivityCheck $success_log $error_log
        if($repository_available -eq $true) { 
            $maintenance_success = Invoke-Maintenance $success_log $error_log

            # $maintenance_success = ($maintenance_success -eq $true) -and (!(Test-Path $error_log) -or ((Get-Item $error_log).Length -eq 0))
            $total_attempts = $GlobalRetryAttempts - $attempt_count + 1
            if($maintenance_success -eq $true) {
                Write-Output "[[Maintenance]] Succeeded after $total_attempts attempt(s)" | Tee-Object -Append $success_log
            }
            else {
                Write-Output "[[Maintenance]] Ran with errors on attempt $total_attempts" | Tee-Object -Append $success_log | Tee-Object -Append $error_log
                $error_count++
            }
        }
        else {
            Write-Output "[[Maintenance]] Failed - cannot access repository." | Tee-Object -Append $success_log | Tee-Object -Append $error_log
            $error_count++
        }
        
        $attempt_count--

        # update logs prior to sending email
        if($maintenance_success -eq $false) { 
            if($attempt_count -gt 0) {
                Write-Output "[[Maintenance]] Sleeping for 15 min and then retrying..." | Tee-Object -Append $success_log
            }
            else {
                Write-Output "[[Maintenance]] Retry limit has been reached. No more attempts to run maintenance will be made." | Tee-Object -Append $success_log
            }
        }

        Invoke-HistoryCheck $success_log $error_log "Maintenance"
        Send-Email $success_log $error_log "Maintenance"

        # update the state of the last maintenance success or failure
        $Script:ResticStateLastMaintenanceSuccessful = $maintenance_success
        
        # Save state to file
        Set-BackupState

        # loop exit/wait condition
        if(($maintenance_success -eq $false) -and ($attempt_count -gt 0)) {
            Start-Sleep (15*60)
        }
        else {
            break
        }
    }    

    # Save state to file
    Set-BackupState

    # cleanup older log files
    Get-ChildItem $LogPath | Where-Object {$_.CreationTime -lt $(Get-Date).AddDays(-$LogRetentionDays)} | Remove-Item

    exit $error_count
}

Invoke-Main
