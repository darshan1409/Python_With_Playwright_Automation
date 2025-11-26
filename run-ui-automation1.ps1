param(
    [string]$ENV,
    [string]$UserEmail,
    [string]$PasswordBase64Json,
    [string]$AdoPat
)

Write-Host "=== PowerShell Test Runner Started ==="
Write-Host "ENV = $ENV"
Write-Host "UserEmail = $UserEmail"

# Decode password
$decoded1 = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($PasswordBase64Json))
$PASSWORD = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($decoded1))

Write-Host "Decoded Password: $PASSWORD"

$pytestArgs = @(
    ".\tests\distributor_tests\test_dcn_assignment_page.py::test_assign_dcn_to_customer",
    "--env", $env:ENV,
    "--useremail", $env:USEREMAIL,
    "--password", $env:PASSWORD,
    "--browser", "chromium",
    "-v",
    "-s"
)


pytest @pytestArgs
