# Changelog

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
