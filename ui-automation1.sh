#!/usr/bin/env bash
set -euo pipefail
trap 'echo "ERROR at line $LINENO: $BASH_COMMAND"' ERR

REGION="${REGION:-us-east-1}"
INSTANCE_ID="$1"
ENV="$2"
USEREMAIL="$3"
PASSWORD="$4"
ADO_PAT_TOKEN="$5"

if [[ -z "$INSTANCE_ID" ]]; then
  echo "Usage: $0 INSTANCE_ID ENV USEREMAIL PASSWORD ADO_PAT"
  exit 1
fi

echo "Checking SSM status..."
INFO=$(aws ssm describe-instance-information \
  --region "$REGION" \
  --query "InstanceInformationList[?InstanceId=='${INSTANCE_ID}'].[PingStatus,PlatformType]" \
  --output text)

STATUS=$(awk '{print $1}' <<<"$INFO")
PLATFORM=$(awk '{print $2}' <<<"$INFO")

[[ "$STATUS" != "Online" ]] && { echo "Instance offline"; exit 1; }
[[ "$PLATFORM" != "Windows" ]] && { echo "Not a Windows instance"; exit 1; }

echo "Encoding password..."

PASSWORD_B64=$(printf "%s" "$PASSWORD" | base64 -w 0)
PASSWORD_B64_JSON=$(printf "%s" "$PASSWORD_B64" | base64 -w 0)

echo "Password_B64_JSON => $PASSWORD_B64_JSON"

#############################
# IMPORTANT — FIXED GIT URL
#############################

GIT_URL="https://USERNAME:${ADO_PAT_TOKEN}@cgna-stg.visualstudio.com/Foodbuy/_git/foodbuy-qa-automation"

#############################
# BUILD JSON
#############################

read -r -d '' COMMANDS_JSON <<EOF
{
  "commands": [
    "Set-Location C:\\\\Temp",
    "if (Test-Path foodbuy-qa-automation) { cd foodbuy-qa-automation; git fetch --all; git checkout feature/ui-automation-azure-pipelines; git pull origin feature/ui-automation-azure-pipelines } else { git clone -b feature/ui-automation-azure-pipelines \"$GIT_URL\" foodbuy-qa-automation; cd foodbuy-qa-automation }",
    "Write-Host '=== Running UI Automation Tests ==='",
    "powershell -ExecutionPolicy Bypass -File C:\\\\Temp\\\\foodbuy-qa-automation\\\\run-ui-automation.ps1 '${ENV}' '${USEREMAIL}' '${PASSWORD_B64_JSON}' '${ADO_PAT_TOKEN}'"
  ]
}
EOF

echo "Built JSON successfully."

# No jq (it breaks for escaped Windows JSON)
echo "$COMMANDS_JSON"

CMD_ID=$(aws ssm send-command \
  --region "$REGION" \
  --document-name "AWS-RunPowerShellScript" \
  --comment "Run UI Playwright Tests" \
  --instance-ids "$INSTANCE_ID" \
  --parameters file://<(echo "$COMMANDS_JSON") \
  --query 'Command.CommandId' --output text)

aws ssm wait command-executed --region "$REGION" --command-id "$CMD_ID" --instance-id "$INSTANCE_ID"

aws ssm get-command-invocation \
  --region "$REGION" \
  --command-id "$CMD_ID" \
  --instance-id "$INSTANCE_ID" \
  --query '{Status:Status, StdOut:StandardOutputContent, StdErr:StandardErrorContent, ExitCode:ResponseCode}'
