. .\config.ps1
. .\secrets.ps1

# download restic
if(-not (Test-Path $ResticExe)) {
    $url = $null
    if([Environment]::Is64BitOperatingSystem){
        $url = "https://github.com/restic/restic/releases/download/v0.17.3/restic_0.17.3_windows_amd64.zip"
    }
    else {
        $url = "https://github.com/restic/restic/releases/download/v0.17.3/restic_0.17.3_windows_386.zip"
    }
    $output = Join-Path $InstallPath "restic.zip"
    Invoke-WebRequest -Uri $url -OutFile $output
    Expand-Archive -LiteralPath $output $InstallPath
    Remove-Item $output
    Get-ChildItem *.exe | Rename-Item -NewName $ExeName
}

# Invoke restic self-update to check for a newer version
& $ResticExe self-update

# Create log directory if it doesn't exit
if(-not (Test-Path $LogPath)) {
    New-Item -ItemType Directory -Force -Path $LogPath | Out-Null
    Write-Output "[[Init]] Repository successfully initialized."
}

# Create the local exclude file
if(-not (Test-Path $LocalExcludeFile)) {
    New-Item -Type File -Path $LocalExcludeFile | Out-Null
}

# Initialize the restic repository
& $ResticExe --verbose init
if($?) {
    Write-Output "[[Init]] Repository successfully initialized."
}
else {
    Write-Warning "[[Init]] Repository initialization failed. Check errors and resolve."
}

# Scheduled Windows Task Scheduler to run the backup
$backup_task_name = "Restic Backup"
$backup_task = Get-ScheduledTask $backup_task_name -ErrorAction SilentlyContinue
if($null -eq $backup_task) {
    try {
        $task_action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument '-ExecutionPolicy Bypass -NonInteractive -NoLogo -NoProfile -Command ".\backup.ps1; exit $LASTEXITCODE"' -WorkingDirectory $InstallPath
        $task_user = New-ScheduledTaskPrincipal -UserId "NT AUTHORITY\SYSTEM" -RunLevel Highest
        $task_settings = New-ScheduledTaskSettingsSet -RestartCount 4 -RestartInterval (New-TimeSpan -Minutes 15) -ExecutionTimeLimit (New-TimeSpan -Days 3) -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -DontStopOnIdleEnd -MultipleInstances IgnoreNew -IdleDuration 0 -IdleWaitTimeout 0 -StartWhenAvailable -RestartOnIdle
        $task_trigger = New-ScheduledTaskTrigger -Daily -At 4:00am
        Register-ScheduledTask $backup_task_name -Action $task_action -Principal $task_user -Settings $task_settings -Trigger $task_trigger | Out-Null
        Write-Output "[[Scheduler]] Backup task scheduled."
    }
    catch {
        Write-Warning "[[Scheduler]] Scheduling failed."
    }
}
else {
    Write-Warning "[[Scheduler]] Backup task not scheduled: there is already a task with the name '$backup_task_name'."
}


