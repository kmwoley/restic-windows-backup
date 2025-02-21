# Changelog

## [1.8](https://github.com/kmwoley/restic-windows-backup/tree/1.8) (2025-02-20)
[Full Changelog](https://github.com/kmwoley/restic-windows-backup/compare/1.7.1...1.8)

## Summary
* New features
  * Added `update.ps1` which makes updating `restic-windows-backup` installations easier.
  * Added the ability to run custom actions at the start and end of the script execution. Can be used to invoke healthchecks or run custom scripts. Look at `config_sample.ps1` for examples.

* Bug fixes
  * Explicitly test the backup source media for VSS support instead of assuming it is or is not supported
  * Install script sets Task Scheduler user LogonType correctly, fixing #40
  * Error checking of restic.exe results fixed (was broken by release 1.7.1)

## [1.7.1](https://github.com/kmwoley/restic-windows-backup/tree/1.7.1) (2025-02-03)
[Full Changelog](https://github.com/kmwoley/restic-windows-backup/compare/1.7...1.7.1)

## Summary
* (Optionally) prevent backup & maintenance while on a metered network connection. By default, backups will occur while on a metered network connection. To disable backups over metered network connections, set `$BackupOnMeteredNetwork = $false` in `config.ps1`
* Added `$GlobalParameters = @()` configuration variable, which will apply additional configuration parameters every time `restic.exe` is run. This is useful to add options for different types of backend targets.
* Added `$SelfUpdateEnabled = $true` configuration variable, which can be used to disable `restic.exe` from automatically updating to the latest version when maintenance is run. To disable self update, set `$SelfUpdateEnabled = $false` in `config.ps1`
 
## What's Changed
* Add optional configuration options for additional parameters to resti… by @woelfisch in https://github.com/kmwoley/restic-windows-backup/pull/96
* Add feature to control backups on metered connections by @innovara in https://github.com/kmwoley/restic-windows-backup/pull/108

## New Contributors
* @woelfisch made their first contribution in https://github.com/kmwoley/restic-windows-backup/pull/96

## [1.7](https://github.com/kmwoley/restic-windows-backup/tree/1.7) (2025-01-25)
[Full Changelog](https://github.com/kmwoley/restic-windows-backup/compare/1.6...1.7)

*Upgrade Warning - Future Breaking Change*
This release deprecates the following `secrets.ps1` variables:
* `$PSEmailServer` is replaced by `$ResticEmailServer`
* `$ResticEmailConfig` is replaced by `$ResticEmailPort`
In the next release, `$ResticEmailServer` and `$ResticEmailPort` will be required. This release will still work if the deprecated variables are defined.

## What's Changed
* Update README.md by @enzo-g in https://github.com/kmwoley/restic-windows-backup/pull/58
* fix typo in readme by @jonas-hag in https://github.com/kmwoley/restic-windows-backup/pull/74
* fix typo by @Export33 in https://github.com/kmwoley/restic-windows-backup/pull/83
* Added a more detailed example for backup sources by @Export33 in https://github.com/kmwoley/restic-windows-backup/pull/84
* Limit snapshot pruning to the current host by @living180 in https://github.com/kmwoley/restic-windows-backup/pull/94
* Allow for unauthenticated SMTP. by @SeeJayEmm in https://github.com/kmwoley/restic-windows-backup/pull/81
* Replace deprecated Send-MailMessage with Send-MailKitMessage by @innovara in https://github.com/kmwoley/restic-windows-backup/pull/107
* Merge 2024.11 into Main by @kmwoley in https://github.com/kmwoley/restic-windows-backup/pull/110

## New Contributors
* @enzo-g made their first contribution in https://github.com/kmwoley/restic-windows-backup/pull/58
* @jonas-hag made their first contribution in https://github.com/kmwoley/restic-windows-backup/pull/74
* @Export33 made their first contribution in https://github.com/kmwoley/restic-windows-backup/pull/83
* @living180 made their first contribution in https://github.com/kmwoley/restic-windows-backup/pull/94
* @SeeJayEmm made their first contribution in https://github.com/kmwoley/restic-windows-backup/pull/81
* @innovara made their first contribution in https://github.com/kmwoley/restic-windows-backup/pull/107

## [1.6](https://github.com/kmwoley/restic-windows-backup/tree/1.6) (2023-01-14)
[Full Changelog](https://github.com/kmwoley/restic-windows-backup/compare/1.5...1.6)

Separated backup and maintenance execution loops, including sending separate emails for backup and maintenance reports. This allows for a maintenance failure not to cause a backup to be re-run, and vice-versa. This makes failures take a shorter time to resolve.	

Logfiles now are formated as `*.backup.log.txt` and `*.maintenance.log.txt`

## Fixes
- Fixed issue #60, removing duplicate exclude lines
- Fixed several errors where functions would return incorrect success/failure results due to PowerShell's return value semantics

## Enhancements
- Updated installer to download v 0.15.0
- Installer will 'self-update' the Restic binary
- Maintenance will 'self-update' the Restic binary
- Added a configuration point for extra / additional parameters to be passed to the backup command (`$AdditionalBackupParameters`)
	
## [1.5](https://github.com/kmwoley/restic-windows-backup/tree/1.5) (2021-09-11)
[Full Changelog](https://github.com/kmwoley/restic-windows-backup/compare/1.4.1...1.5)

Added support for backing up removable drives (i.e. external USB disks). It's now possible to define a backup source by it's Volume label, device Serial Number, or the hardware Name. 

**WARNING** If you have been previously backing up multiple drives, the default `forget` policy was likely pruning backup sets too aggressively and could lead to data loss. You **must** update your `$SnapshotRetentionPolicy` to include `@("--group-by", "host,tags", ...` to avoid pruning an entire drive's contents inadvertently! 

## Fixes
- Updated default snapshot forget/prune retention policy to group by "host,tags" to prevent major data loss. Only configurations with multiple `$BackupSources` are impacted by this change.
- Added tags to each backup source to support grouping by tags. For existing backup sets, this change will result in a slightly longer backup the first time this updated script is run.

## Enhancements
- External, removable disk drives (i.e. USB hard drives) can be identified by their Volume Label, Serial Number, or Device Name. For example, if you have an external device with the Volume Label "MY BOOK", you can define a backup source as `$BackupSources["MY BOOK"]`. I would recommend using the device serial number to identify external drives to backup, which you can find using the Powershell `get-disk` command.
- Add the ability to $IgnoreMissingBackupSources. To make sure that errors are not thrown if the device is not present, there is now an option to ignore error reporting when a folder and entire backup source are missing. When `$true`, missing external drives or folders don't produce errors. When `$null` or `$false`, missing drives and/or folders result in an error. The default is set to `$false` as not to silently fail backing up a source.
- Updated install script to download Restic 0.12.1

## [1.4.1](https://github.com/kmwoley/restic-windows-backup/tree/1.4.1) (2021-05-29)
[Full Changelog](https://github.com/kmwoley/restic-windows-backup/compare/1.4...1.4.1)

Bugfix release.

## Fixes
- Improved URL parsing so that the internet connectivity check works if the URL doesn't provide a protocol
- Add PowerShell 7.1 support to internet connectivity check

## Enhancements
- Setting $InternetTestAttempts to 0 will now bypass the internet connectivity checks entirely

## [1.4](https://github.com/kmwoley/restic-windows-backup/tree/1.4) (2021-02-24)
[Full Changelog](https://github.com/kmwoley/restic-windows-backup/compare/1.3...1.4)

Moved to using Restic's inbuilt filesystem shadow copy creation (VSS).

## Breaking Change
`local.exclude` file changes that previously referenced the `resticVSS` directory will need to be changed to `C:\` or the relevant root drive letter.

## Other enhancements
- Future snapshot grouping (and cleanup) will be better since the root-level folders included in the backup won't change (instead, the script targets the root drive letter instead of a list of folders under the drive letter).
- Added the ability to set prune parameters via `.\config.ps1`, and defaulted the settings to `--group-by host` to clean up the aforementioned snapshot grouping & pruning.
- Updated the `windows.exclude` to include additional directories (most notably, the Recycle Bin is no longer backed up) 

**Closed issues:**

- Remove VSS Operations, Switch to `--use-fs-snapshot` [\#32](https://github.com/kmwoley/restic-windows-backup/issues/32)
- powershell execution policy is blocking the scheduled task [\#27](https://github.com/kmwoley/restic-windows-backup/issues/27)
- VSS Cleanup Upon Errors [\#8](https://github.com/kmwoley/restic-windows-backup/issues/8)

**Merged pull requests:**

- Release 1.4 [\#33](https://github.com/kmwoley/restic-windows-backup/pull/33) ([kmwoley](https://github.com/kmwoley))

## [1.3](https://github.com/kmwoley/restic-windows-backup/tree/1.3) (2021-02-23)

[Full Changelog](https://github.com/kmwoley/restic-windows-backup/compare/1.2.1...1.3)

Improvements for Restic 0.12 and additional error logging.

**Closed issues:**

- backup errors after update to restic 0.12.0 due to --quiet and --verbose being used simultaneously [\#29](https://github.com/kmwoley/restic-windows-backup/issues/29)
- Restic + rclone errors [\#26](https://github.com/kmwoley/restic-windows-backup/issues/26)
- E-Mail sending errors are not logged [\#25](https://github.com/kmwoley/restic-windows-backup/issues/25)
- FYI: Restic now has built-in VSS support [\#23](https://github.com/kmwoley/restic-windows-backup/issues/23)
- SFTP backup [\#22](https://github.com/kmwoley/restic-windows-backup/issues/22)
- Dirrectory/Folder Backup [\#21](https://github.com/kmwoley/restic-windows-backup/issues/21)
- Docker format [\#20](https://github.com/kmwoley/restic-windows-backup/issues/20)
- Filtering out errors before deciding to retry ? [\#19](https://github.com/kmwoley/restic-windows-backup/issues/19)
- Backup task stucked [\#18](https://github.com/kmwoley/restic-windows-backup/issues/18)

**Merged pull requests:**

- Release 1.4 [\#31](https://github.com/kmwoley/restic-windows-backup/pull/31) ([kmwoley](https://github.com/kmwoley))
- Add '-ExecutionPolicy Bypass' to the task scheduler arguments to avoi… [\#28](https://github.com/kmwoley/restic-windows-backup/pull/28) ([scelfo](https://github.com/scelfo))
- Fix URI parsing [\#24](https://github.com/kmwoley/restic-windows-backup/pull/24) ([Phlogi](https://github.com/Phlogi))

## [1.2.1](https://github.com/kmwoley/restic-windows-backup/tree/1.2.1) (2020-06-08)

[Full Changelog](https://github.com/kmwoley/restic-windows-backup/compare/1.1...1.2.1)

* Internet connectivity test now supports more repository types (s3:, sftp:, rest:, azure:, gs:), and ignores unsupported (swift:, rclone: and local) 
* Add 32-bit support in the `install.ps1`

* Fix/improve internet connectivity checks for azure: gs: b2:

**Closed issues:**

- azure repo could not be parsed [\#15](https://github.com/kmwoley/restic-windows-backup/issues/15)
- Need to strip rest: in addition to s3: from RESTIC\_REPOSITORY [\#14](https://github.com/kmwoley/restic-windows-backup/issues/14)
- Use non-s3 repos [\#10](https://github.com/kmwoley/restic-windows-backup/issues/10)
- Test-Connection fails [\#9](https://github.com/kmwoley/restic-windows-backup/issues/9)
- 32bit Windows Support [\#7](https://github.com/kmwoley/restic-windows-backup/issues/7)
- Add changelog [\#1](https://github.com/kmwoley/restic-windows-backup/issues/1)

**Merged pull requests:**

- Release 1 3 [\#17](https://github.com/kmwoley/restic-windows-backup/pull/17) ([kmwoley](https://github.com/kmwoley))
- 1.2 Release [\#13](https://github.com/kmwoley/restic-windows-backup/pull/13) ([kmwoley](https://github.com/kmwoley))

## [1.1](https://github.com/kmwoley/restic-windows-backup/tree/1.1) (2020-02-15)

[Full Changelog](https://github.com/kmwoley/restic-windows-backup/compare/1.0...1.1)

* Users can now set the following variables to control sending emails on success and/or error conditions.
* Users can now completely disable maintenance activities.

New `config.ps1` variable defaults for these options are:
```
$SnapshotMaintenanceEnabled = $true 
$SendEmailOnSuccess = $false
$SendEmailOnError = $true
```

**Closed issues:**

- Ability to disable maintenance [\#3](https://github.com/kmwoley/restic-windows-backup/issues/3)
- Ability to disable mail sending [\#2](https://github.com/kmwoley/restic-windows-backup/issues/2)

**Merged pull requests:**

- add changelog [\#6](https://github.com/kmwoley/restic-windows-backup/pull/6) ([kmwoley](https://github.com/kmwoley))
- add options to enable/disable email sending  and maintenance [\#4](https://github.com/kmwoley/restic-windows-backup/pull/4) ([kmwoley](https://github.com/kmwoley))

## [1.0](https://github.com/kmwoley/restic-windows-backup/tree/1.0) (2020-02-09)

[Full Changelog](https://github.com/kmwoley/restic-windows-backup/compare/34eae241aa1dcf08ed1d4d4f930e1d1a5bf5788a...1.0)



\* *This Changelog was automatically generated by [github_changelog_generator](https://github.com/github-changelog-generator/github-changelog-generator)*
