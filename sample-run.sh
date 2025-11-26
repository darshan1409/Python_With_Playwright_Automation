#!/usr/bin/env bash
set -euo pipefail

ENV="${1:-STAGE}"
USEREMAIL="${2:-}"
PASSWORD="${3:-}"
ADO_PAT_TOKEN="${4:-}"

echo "=== Input Arguments ==="
echo "ENV: $ENV"
echo "USEREMAIL: $USEREMAIL"
echo "PASSWORD: $PASSWORD"
echo "ADO_PAT_TOKEN: $ADO_PAT_TOKEN"

# Step 1: Base64 encode password (one line, safe for Git Bash)
PASSWORD_B64=$(printf "%s" "$PASSWORD" | base64 -w 0)
PASSWORD_B64_JSON=$(printf "%s" "$PASSWORD_B64" | base64 -w 0)

echo "PASSWORD_B64: $PASSWORD_B64"
echo "PASSWORD_B64_JSON: $PASSWORD_B64_JSON"

#############################################
# BUILD LOCAL COMMANDS_JSON (NO AWS)
#############################################

COMMANDS_JSON=$(cat <<EOF
{
  "commands": [
    "Set-Location C:\\\\Temp",
    "Write-Host '=== Running UI Automation Tests (LOCAL SIMULATION) ==='",
    "powershell -ExecutionPolicy Bypass -File C:\\\\Temp\\\\run-ui-automation.ps1 '${ENV}' '${USEREMAIL}' '${PASSWORD_B64_JSON}' '${ADO_PAT_TOKEN}'"
  ]
}
EOF
)

echo ""
echo "=== GENERATED JSON (LOCAL TEST) ==="
# print pretty if jq exists, otherwise print raw
if command -v jq >/dev/null 2>&1; then
  echo "$COMMANDS_JSON" | jq .
else
  echo "$COMMANDS_JSON"
fi

#############################################
# SIMULATE EXECUTING THE POWERSHELL COMMAND
#############################################

echo ""
echo "=== SIMULATING EXECUTION ==="
# Use built-in Windows PowerShell (powershell.exe) so default Windows works
# We pass the same args the pipeline would pass (powershell will decode)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File run-ui-automation.ps1 "$ENV" "$USEREMAIL" "$PASSWORD_B64_JSON" "$ADO_PAT_TOKEN"
