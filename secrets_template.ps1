# Template file for backup destination configuration and email passwords.
# Update this file to point to your restic repository and email service.
# Rename to `secrets.ps1`

# restic backup repository configuration
$Env:AWS_ACCESS_KEY_ID='<KEY>'
$Env:AWS_SECRET_ACCESS_KEY='<KEY>'
$Env:RESTIC_REPOSITORY='<REPO URL>'
$Env:RESTIC_PASSWORD='<BACKUP PASSWORD>'

# email configuration
$ResticEmailServer='<SMTP SERVER>'
$ResticEmailPort='<SMTP PORT NUMBER, i.e. 25 or 587>'
$ResticEmailTo='<DESTINATION EMAIL ADDRESS>'
$ResticEmailFrom='<FROM EMAIL ADDRESS>'
$ResticEmailUsername='<EMAIL LOGIN USERNAME OR EMPTY FOR NO USERNAME>'
$ResticEmailPassword='<EMAIL PASSWORD OR EMPTY FOR NO PASSWORD>'
