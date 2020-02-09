# restic-windows-backup
Powershell scripts to run Restic backups on Windows.
Simplifies the process of installation and running daily backups.

# Features
* **VSS (Volume Snapshot Service) support** - backup everything, don't worry about what files are open/in-use
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
   1. If you downloaded the files as a ZIP file, you may have to 'unblock' the execution of the scripts by running `Unblock-File *.ps1`
1. Create `secrets.ps1` file
   1. The secrets file contains location and passwords for your restic repository.
   1. `secrets_template.ps1` is a template for the `secrets.ps1` file - copy or rename this file to `secrets.ps1` and edit.
   1. restic will pick up the repo destination from the environment variables you set in this file - see this doc for more information about configuring restic repos https://restic.readthedocs.io/en/latest/030_preparing_a_new_repo.html
   1. Email sending configuration is also contained with this file. The scripts assume you want to get emails about the success/failure of each backup attempt.
1. Run `install.ps1` file
   1. From the elevated (Run as Administrator) Powershell window, run `.\install.ps1`
   1. This will initialize the repro, create your logfile directory, and create a scheduled task in Windows Task Scheduler to run the task daily.
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

# Feedback?
Feel free to open issues or create PRs!
