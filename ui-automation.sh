# ssm-run-ui-tests.sh
#!/usr/bin/env bash
set -euo pipefail
trap 'echo "ERROR at line $LINENO: $BASH_COMMAND"' ERR

REGION="${REGION:-us-east-1}"
INSTANCE_ID="${1:-}"
ENV="${2:-}"
USEREMAIL="${3:-}"
PASSWORD="${4:-}"
ADO_PAT_TOKEN="${5:-}"

if [[ -z "${INSTANCE_ID}" ]]; then
  echo "Usage: REGION=us-east-1 $0 i-0123456789abcdef0 ENV USEREMAIL PASSWORD ADO_PAT"
  exit 1
fi

echo "Checking SSM status for ${INSTANCE_ID} in ${REGION}..."
INFO=$(aws ssm describe-instance-information \
  --region "$REGION" \
  --query "InstanceInformationList[?InstanceId=='${INSTANCE_ID}'].[PingStatus,PlatformType]" \
  --output text)

STATUS=$(awk '{print $1}' <<<"$INFO")
PLATFORM=$(awk '{print $2}' <<<"$INFO")

if [[ -z "${STATUS:-}" ]]; then
  echo "Instance not found in SSM inventory."
  exit 2
fi

if [[ "$STATUS" != "Online" ]]; then
  echo "Instance not Online in SSM (status=$STATUS)."
  exit 2
fi

if [[ "$PLATFORM" != "Windows" ]]; then
  echo "This script is only for Windows EC2 instances."
  exit 3
fi

echo "Sending UI test command..."

PASSWORD_B64=$(printf "%s" "$PASSWORD" | base64 -w 0)
echo "BASE64==>${PASSWORD_B64}<=="

# Step 2: Base64 encode again for JSON safety
PASSWORD_B64_JSON=$(printf "%s" "$PASSWORD_B64" | base64)
echo "PASSWORD_B64_JSON==>${PASSWORD_B64_JSON}<=="

COMMANDS_JSON=$(cat <<EOF
{
  "commands": [
    "Set-Location C:\\\\Temp",
    "if (Test-Path foodbuy-qa-automation) { cd foodbuy-qa-automation; git fetch --all; git checkout feature/ui-automation-azure-pipelines; git pull origin feature/ui-automation-azure-pipelines } else { git clone -b feature/ui-automation-azure-pipelines https://Baral, Astha .:\$(env:ADO_PAT_TOKEN)@cgna-stg.visualstudio.com/Foodbuy/_git/foodbuy-qa-automation foodbuy-qa-automation; cd foodbuy-qa-automation }",
    "Write-Host '=== Running UI Automation Tests ==='",
    "powershell -ExecutionPolicy Bypass -File C:\\\\Temp\\\\foodbuy-qa-automation\\\\run-ui-automation.ps1 '${ENV}' '${USEREMAIL}' '${PASSWORD_B64_JSON}' '${ADO_PAT_TOKEN}'"
  ]
}
EOF
)

echo "DEBUG: Sending SSM command..."
echo "$COMMANDS_JSON" | jq .

set -x
CMD_ID=$(aws ssm send-command \
  --region "$REGION" \
  --document-name "AWS-RunPowerShellScript" \
  --comment "Run UI Playwright Tests" \
  --instance-ids "$INSTANCE_ID" \
  --parameters file://<(echo "$COMMANDS_JSON") \
  --query 'Command.CommandId' --output text)
set +x

echo "Waiting for command ${CMD_ID} to finish..."
aws ssm wait command-executed \
  --region "$REGION" \
  --command-id "$CMD_ID" \
  --instance-id "$INSTANCE_ID"

echo "Fetching output:"
aws ssm get-command-invocation \
  --region "$REGION" \
  --command-id "$CMD_ID" \
  --instance-id "$INSTANCE_ID" \
  --query '{Status:Status, StdOut:StandardOutputContent, StdErr:StandardErrorContent, ExitCode:ResponseCode}'
