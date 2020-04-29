# Changelog

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

- add options to enable/disable email sending  and maintenance [\#4](https://github.com/kmwoley/restic-windows-backup/pull/4) ([kmwoley](https://github.com/kmwoley))

## [1.0](https://github.com/kmwoley/restic-windows-backup/tree/1.0) (2020-02-09)

[Full Changelog](https://github.com/kmwoley/restic-windows-backup/compare/34eae241aa1dcf08ed1d4d4f930e1d1a5bf5788a...1.0)



\* *This Changelog was automatically generated by [github_changelog_generator](https://github.com/github-changelog-generator/github-changelog-generator)*