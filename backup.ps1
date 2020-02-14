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
        & $ResticExe unlock 3>&1 2>> $ErrorLog | Tee-Object -Append $SuccessLog
        Write-Output "[[Unlock]] Repository was locked. Unlocking. Past script failure?" | Tee-Object -Append $ErrorLog | Tee-Object -Append $SuccessLog
        Start-Sleep 120 
    }
}

# run maintenance on the backup set
function Invoke-Maintenance {
    Param($SuccessLog, $ErrorLog)
    
    # skip maintenance if disabled
    if($SnapshotMaintenanceEnabled -eq $false) {
        Write-Output "[[Maintenance]] Skipped - maintenance disabled" | Tee-Object -Append $SuccessLog
        return
    }

    # skip maintenance if it's been done recently
    if(($null -ne $ResticStateLastMaintenance) -and ($null -ne $ResticStateMaintenanceCounter)) {
        $Script:ResticStateMaintenanceCounter += 1
        $delta = New-TimeSpan -Start $ResticStateLastMaintenance -End $(Get-Date)
        if(($delta.Days -lt $SnapshotMaintenanceDays) -and ($ResticStateMaintenanceCounter -lt $SnapshotMaintenanceInterval)) {
            Write-Output "[[Maintenance]] Skipped - last maintenance $ResticStateLastMaintenance ($($delta.Days) days, $ResticStateMaintenanceCounter backups ago)" | Tee-Object -Append $SuccessLog
            return
        }
    }

    Write-Output "[[Maintenance]] Start $(Get-Date)" | Tee-Object -Append $SuccessLog
    $maintenance_success = $true
    Start-Sleep 120

    # forget snapshots based upon the retention policy
    Write-Output "[[Maintenance]] Start forgetting..." | Tee-Object -Append $SuccessLog
    & $ResticExe --verbose -q forget $SnapshotRetentionPolicy 3>&1 2>> $ErrorLog | Tee-Object -Append $SuccessLog
    if(-not $?) {
        Write-Output "[[Maintenance]] Forget operation completed with errors" | Tee-Object -Append $ErrorLog | Tee-Object -Append $SuccessLog
        $maintenance_success = $false
    }

    # prune (remove) data from the backup step. Running this separate from `forget` because
    #   `forget` only prunes when it detects removed snapshots upon invocation, not previously removed
    Write-Output "[[Maintenance]] Start pruning..." | Tee-Object -Append $SuccessLog
    & $ResticExe --verbose -q prune 3>&1 2>> $ErrorLog | Tee-Object -Append $SuccessLog
    if(-not $?) {
        Write-Output "[[Maintenance]] Prune operation completed with errors" | Tee-Object -Append $ErrorLog | Tee-Object -Append $SuccessLog
        $maintenance_success = $false
    }

    # check data to ensure consistency
    Write-Output "[[Maintenance]] Start checking..." | Tee-Object -Append $SuccessLog

    # check to determine if we want to do a full data check or not
    $data_check = @()
    if($null -ne $ResticStateLastDeepMaintenance) {
        $delta = New-TimeSpan -Start $ResticStateLastDeepMaintenance -End $(Get-Date)
        if($delta.Days -ge $SnapshotDeepMaintenanceDays) {
            Write-Output "[[Maintenance]] Performing full data check - deep '--read-data' check last ran $ResticStateLastDeepMaintenance ($($delta.Days) days ago)" | Tee-Object -Append $SuccessLog
            $data_check = @("--read-data")
            $Script:ResticStateLastDeepMaintenance = Get-Date
        }
        else {
            Write-Output "[[Maintenance]] Performing fast data check - deep '--read-data' check last ran $ResticStateLastDeepMaintenance ($($delta.Days) days ago)" | Tee-Object -Append $SuccessLog
        }
    }
    else {
        # set the date, but don't do a deep check if we've never done a full data read
        $Script:ResticStateLastDeepMaintenance = Get-Date
    }

    & $ResticExe --verbose -q check @data_check 3>&1 2>> $ErrorLog | Tee-Object -Append $SuccessLog
    if(-not $?) {
        Write-Output "[[Maintenance]] Check completed with errors" | Tee-Object -Append $ErrorLog | Tee-Object -Append $SuccessLog
        $maintenance_success = $false
    }

    Write-Output "[[Maintenance]] End $(Get-Date)" | Tee-Object -Append $SuccessLog
    
    if($maintenance_success -eq $true) {
        $Script:ResticStateLastMaintenance = Get-Date
        $Script:ResticStateMaintenanceCounter = 0;
    }
}

# Run restic backup 
function Invoke-Backup {
    Param($SuccessLog, $ErrorLog)

    Write-Output "[[Backup]] Start $(Get-Date)" | Tee-Object -Append $SuccessLog
    $return_value = $true
    $drive_count = $BackupSources.Count
    $starting_location = Get-Location
    ForEach ($item in $BackupSources.GetEnumerator()) {

        $ShadowPath = Join-Path $item.Key 'resticVSS'

        # check for existance of previous, orphaned VSS directory (and remove it) before creating the shadow copy
        if(Test-Path $ShadowPath) {
            Write-Output "[[Backup]] VSS directory exists: '$ShadowPath' - removing. Past script failure?" | Tee-Object -Append $ErrorLog | Tee-Object -Append $SuccessLog
            cmd /c rmdir $ShadowPath
        }
        
        # Create the shadow copy
        $s1 = (Get-WmiObject -List Win32_ShadowCopy).Create($item.Key, "ClientAccessible")
        $s2 = Get-WmiObject -Class Win32_ShadowCopy | Where-Object { $_.ID -eq $s1.ShadowID }
        
        # Create a symbolic link to the shadow copy
        $device  = $s2.DeviceObject + "\"
        cmd /c mklink /d $ShadowPath "$device" 3>&1 2>> $ErrorLog | Tee-Object -Append $SuccessLog

        # Build the new list of folders
        $root_path = $ShadowPath
        if($drive_count -eq 1) {
            $root_path = "."
            Set-Location $ShadowPath
        }

        $folder_list = New-Object System.Collections.Generic.List[System.Object]
        ForEach ($path in $item.Value) {
            $p = Join-Path $root_path $path
            $folder_list.Add($p)
        }

        # backup everything in the root if no folders are provided
        # note this won't select items with hidden attributes (a good thing to avoid)
        if (-not $folder_list) {
            ForEach ($path in Get-ChildItem $ShadowPath) {
                $p = Join-Path $root_path $path
                $folder_list.Add($p)
            }
        }

        # Launch Restic
        & $ResticExe --verbose -q backup $folder_list --exclude-file=$WindowsExcludeFile --exclude-file=$LocalExcludeFile 3>&1 2>> $ErrorLog | Tee-Object -Append $SuccessLog
        if(-not $?) {
            Write-Output "[[Backup]] Completed with errors" | Tee-Object -Append $ErrorLog | Tee-Object -Append $SuccessLog
            $return_value = $false
        }

        # Delete the shadow copy and remove the symbolic link
        if($drive_count -eq 1) {
            Set-Location $starting_location
        }
        $s2.Delete()
        cmd /c rmdir $ShadowPath

        Write-Output "[[Backup]] End $(Get-Date)" | Tee-Object -Append $SuccessLog
    }

    return $return_value
}

function Send-Email {
    Param($SuccessLog, $ErrorLog)
    $password = ConvertTo-SecureString $ResticEmailPassword -AsPlainText -Force
    $credentials = New-Object System.Management.Automation.PSCredential ($ResticEmailUsername, $password)

    $status = "SUCCESS"
    $body = ""
    if (($null -ne $SuccessLog) -and (Test-Path $SuccessLog) -and (Get-Item $SuccessLog).Length -gt 0) {
        $body = $(Get-Content -Raw $SuccessLog)
    }
    else {
        $body = "Crtical Error! Restic backup log is empty or missing. Check log file path."
        $status = "ERROR"
    }
    $attachments = @{}
    if (($null -ne $ErrorLog) -and (Test-Path $ErrorLog) -and (Get-Item $ErrorLog).Length -gt 0) {
        $attachments = @{Attachments = $ErrorLog}
        $status = "ERROR"
    }
    if((($status -eq "SUCCESS") -and ($SendEmailOnSuccess -ne $false)) -or (($status -eq "ERROR") -and ($SendEmailOnError -ne $false))) {
        $subject = "$env:COMPUTERNAME Restic Backup Report [$status]"
        Send-MailMessage @ResticEmailConfig -From $ResticEmailFrom -To $ResticEmailTo -Credential $credentials -Subject $subject -Body $body @attachments
    }
}

function Invoke-ConnectivityCheck {
    Param($SuccessLog, $ErrorLog)
    
    # parse connection string for hostname
    # TODO: handle non-s3 repositories
    #   Uri parser doesn't handle leading connection type info
    $connection_string = $env:RESTIC_REPOSITORY -replace "s3:" 
    $repository_host = ([System.Uri]$connection_string).host

    # test for internet connectivity
    $connections = 0
    $sleep_count = $InternetTestAttempts
    while($true) {
        $connections = Get-NetRoute | Where-Object DestinationPrefix -eq '0.0.0.0/0' | Get-NetIPInterface | Where-Object ConnectionState -eq 'Connected' | Measure-Object | ForEach-Object{$_.Count}
        if($sleep_count -le 0) {
            Write-Output "[[Internet]] Connection to repository could not be established." | Tee-Object -Append $SuccessLog | Tee-Object -Append $ErrorLog
            return $false
        }
        if(($null -eq $connections) -or ($connections -eq 0)) {
            Write-Output "[[Internet]] Waiting for internet connectivity... $sleep_count" | Tee-Object -Append $SuccessLog
            Start-Sleep 30
        }
        elseif(!(Test-Connection -Server $repository_host -Quiet)) {
            Write-Output "[[Internet]] Waiting for connection to repository ($repository_host)... $sleep_count" | Tee-Object -Append $SuccessLog
            Start-Sleep 30
        }
        else {
            return $true
        }
        $sleep_count--
    }
}

# check previous logs
function Invoke-HistoryCheck {
    Param($SuccessLog, $ErrorLog)
    $logs = Get-ChildItem $LogPath -Filter '*err.txt' | %{$_.Length -gt 0}
    $logs_with_success = ($logs | Where-Object {($_ -eq $false)}).Count
    if($logs.Count -gt 0) {
        Write-Output "[[History]] Backup success rate: $logs_with_success / $($logs.Count) ($(($logs_with_success / $logs.Count).tostring("P")))" | Tee-Object -Append $SuccessLog
    }
}

# main function
function Invoke-Main {
    
    # check for elevation, required for creation of shadow copy (VSS)
    if (-not (New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))
    {
        Write-Error "[[Backup]] Elevation required (run as administrator). Exiting."
        exit
    }

    # initialize secrets
    . $SecretsScript
    
    # initialize config
    . $ConfigScript
    
    Get-BackupState

    if(!(Test-Path $LogPath)) {
        Write-Error "[[Backup]] Log file directory $LogPath does not exist. Exiting."
        Send-Email
        exit
    }

    $error_count = 0;
    $attempt_count = $GlobalRetryAttempts
    while ($attempt_count -gt 0) {
        # setup logfiles
        $timestamp = Get-Date -Format FileDateTime
        $success_log = Join-Path $LogPath ($timestamp + ".log.txt")
        $error_log = Join-Path $LogPath ($timestamp + ".err.txt")
        
        $internet_available = Invoke-ConnectivityCheck $success_log $error_log
        if($internet_available -eq $true) { 
            Invoke-Unlock $success_log $error_log
            $backup_success = Invoke-Backup $success_log $error_log
            if($backup_success) {
                Invoke-Maintenance $success_log $error_log
            }

            if (!(Test-Path $error_log) -or ((Get-Item $error_log).Length -eq 0)) {
                # successful with no errors; end
                $total_attempts = $GlobalRetryAttempts - $attempt_count + 1
                Write-Output "Succeeded after $total_attempts attempt(s)" | Tee-Object -Append $success_log
                Invoke-HistoryCheck $success_log $error_log
                Send-Email $success_log $error_log
                break;
            }
        }

        Write-Warning "Errors found! Error Log: $error_log"
        $error_count++
        
        Write-Output "Something went wrong. Sleeping for 15 min and then retrying..." | Tee-Object -Append $success_log
        if($internet_available -eq $true) {
            Invoke-HistoryCheck $success_log $error_log
            Send-Email $success_log $error_log
        }
        Start-Sleep (15*60)
        $attempt_count--
    }    

    Set-BackupState

    # cleanup older log files
    Get-ChildItem $LogPath | Where-Object {$_.CreationTime -lt $(Get-Date).AddDays(-$LogRetentionDays)} | Remove-Item

    exit $error_count
}

Invoke-Main