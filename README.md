# restic-windows-backup
Powershell scripts to run Restic backups on Windows.
Simplifies the process of installation and running daily backups.

# Features
* **VSS (Volume Snapshot Service) support** - backup everything, don't worry about what files are open/in-use
* **Removable, External Drives** - drives can be identified by their volume labels or serial numbers, making it easy to backup drives that occasionally aren't there or change drive letter.
* **Easy Installation** - `install.ps1` script downloads Restic, initializes the restic repository, and setups up a Windows Task Scheduler task to run the backup daily
* **Backup, Maintenance and Monitoring are Automated** - `backup.ps1` script handles
  * Emailing the results of each execution, including log files when there are problems
  * Runs routine maintenence (pruning and checking the repo for errors on a regular basis)
  * And, of course backing up your files.
  
# Installation Instructions

1. Create your restic repository
   1. This is up to you to sort out where you want the data to go to. *Minio, B2, S3, oh my.*
1. Install Scripts
   1. Create script directory: `C:\restic`
   1. Download scripts from https://github.com/kmwoley/restic-windows-backup, and unzip them into `C:\restic`
   1. Launch PowerShell as Administrator
   1. Change your working directory to `C:\restic`
   1. If you haven't done so in the past, set your Powershell script [execution policy](https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_execution_policies?view=powershell-7.1) to allow for scripts to run. For example, `Set-ExecutionPolicy -ExecutionPolicy RemoteSigned` is a good default.
   1. Depending on the policy you choose, may need to 'unblock' the execution of the scripts you download by running `Unblock-File *.ps1`
1. Create `secrets.ps1` file
   1. The secrets file contains location and passwords for your restic repository.
   1. `secrets_template.ps1` is a template for the `secrets.ps1` file - copy or rename this file to `secrets.ps1` and edit.
   1. restic will pick up the repo destination from the environment variables you set in this file - see this doc for more information about configuring restic repos https://restic.readthedocs.io/en/latest/030_preparing_a_new_repo.html
   1. Email sending configuration is also contained with this file. The scripts assume you want to get emails about the success/failure of each backup attempt.
1. Run `install.ps1` file
   1. From the elevated (Run as Administrator) Powershell window, run `.\install.ps1`
   1. This will initialize the repro, create your logfile directory, and create a scheduled task in Windows Task Scheduler to run the task daily.
1. Add your `$BackupSources` to `config.ps1`
   1. By default, all of `C:\` will be backed up. You can add multiple root drives to be backed up. And you can define only specific folders you would like backed up.
   1. External, removalbe disk drives (i.e. USB hard drives) can be identified by their Volume Label, Serial Number, or Device Name. For example, if you have an external device with the Volume Label "MY BOOK", you can define a backup source as `$BackupSources["MY BOOK"]=@()`. I would recommend using the device serial number to identify external drives to backup, which you can find using the Powershell `get-disk` command. You may also want to set `$IgnoreMissingBackupSources=$true` to avoid seeing errors when the removable drive is not present.
1. Add files/paths not to backup to `local.exclude`
   1. If you don't want to modify the included exclude file, you can add any files/paths you want to exclude from the backup to `local.exclude`
1. Add `restic.exe` to the Windows Defender / Virus & Threat Detection Exclude list
   1. Backups on Windows are really slow if you don't set the Antivirus to ignore restic.
   1. Navigate from the Start menu to: *Virus & threat protection > Manage Settings > Exclusions (Add or remove exclusions) > Add an exclusion (Process) > Process Name: "restic.exe"*
1. *(Recommended)* To a test backup triggered from Task Scheduler
   1. It's recommended to open Windows Task Scheduler and trigger the task to run manually to test your first backup.
      1. *Open Task Scheduler > Find "Restic Backup" > Right Click > Run*
   1. The backup script will be executed as the SYSTEM user. Some of your files might not be accessible by this user. If you run into this, add the SYSTEM user to the files where you get "Access Denied" errors.
      1. *Folder > Properties > Security > Advanced > Add ("SYSTEM" Principal/User) > Check "Replace all child object permission entries with inheritable permission entries from this object" > Apply > OK*
1. *(Recommended)* Do a test restore
   1. These scripts make it easy to work with Restic from the Powershell command line. If you run `. .\config.ps1; . .\secrets.ps1` you can then easily invoke restic commands like 
      1. `& $ResticExe find -i "*filename*"`
      1. `& $ResticExe restore ...`

## Backup over SFTP

You can use any restic repository type you like pretty easily. SFTP on Windows, however, can be particularly tricky given that these scripts execute as the SYSTEM user and need to have access to the .ssh keys. Here are some steps and tips to getting it working.

1. Install as above. Your repository should be created properly. Tasked backups will fail for now though. This is because the `install.ps1` file is executed with your user, whereas the tasked backup will run as SYSTEM, which does not have any ssh config yet.
1. Open Task Scheduler and make sure the restic task is not running anymore by checking the active tasks
1. Edit `config.ps1` and turn off the internet connection test: `$InternetTestAttempts = 0` as the test does not recognize sftp addresses correctly
1. Copy the .ssh directory content from `%USERPROFILE%\.ssh` to `%WINDIR%\System32\config\systemprofile\.ssh` (This is the ssh config the SYSTEM account uses)
1. If you use a private key to access the sftp services it also needs to be in this directory. ssh checks the permissions though, so they need to be changed as well:
	1. *Right click your key > Properties > Security > Advanced*
		1. Change the owner to SYSTEM
		1. *Disable inheritance* and keep the permissions
		1. Remove all principals except SYSTEM and the Administrators group 

This should get you up and running. If not, download [PsExec](https://docs.microsoft.com/en-us/sysinternals/downloads/psexec), start a powershell as admin user and run `.\PsExec.exe -s -i powershell.exe`. In this shell you will be the system user and you can try things out. See what `ssh user@server` says or try `cd C:\restic\; . .\config.ps1; . .\secrets.ps1; & $ResticExe check` (If you get lock errors, remember to check the Task Scheduler for any running restic instances in the background) 

# Feedback?
Feel free to open issues or create PRs!
