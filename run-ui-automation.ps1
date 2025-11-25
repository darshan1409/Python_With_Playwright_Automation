param(
    [string]$ENV,
    [string]$USEREMAIL,
    [string]$PASSWORD_B64_JSON,
    [string]$ADO_PAT_TOKEN
)

# Step 1: Decode the JSON-safe Base64
$PASSWORD_B64 = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($PASSWORD_B64_JSON))

# Step 2: Decode original password
$PASSWORD = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($PASSWORD_B64))

# Set environment variables for tests
$env:ENV = $ENV
$env:USEREMAIL = $USEREMAIL
$env:PASSWORD = $PASSWORD
$env:ADO_PAT_TOKEN = $ADO_PAT_TOKEN

Write-Host "=== DEBUG: PowerShell script started ==="
Write-Host "ENV: $ENV"
Write-Host "USEREMAIL: $USEREMAIL"

# Install dependencies
python -m pip install --upgrade pip
pip install -r requirements.txt
pip install pytest pytest-playwright playwright
playwright install chromium

# Prepare pytest arguments safely
$pytestArgs = @(
    ".\tests\distributor_tests\test_dcn_assignment_page.py::test_assign_dcn_to_customer",
    "--env", $env:ENV,
    "--useremail", $env:USEREMAIL,
    "--password", $env:PASSWORD,
    "--browser", "chromium",
    "-v"
)

Write-Host "=== Running UI Automation Tests ==="

# Run pytest using the call operator & to expand the array properly
& pytest @pytestArgs
