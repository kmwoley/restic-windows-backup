# restic-windows-backup
Powershell scripts to run Restic backups on Windows.
Simplifies the process of installation and running.

Features
* `install.ps1` script which downloads Restic, initializes the restic repository, setups up a Windows Task Scheduler task to run the backup daily
* `backup.ps1` script which
  * Emails the results of each execution, including log files when there are problems
  * Handles routine maintenence (forgetting, pruning, and checking the repo on a regular basis)
