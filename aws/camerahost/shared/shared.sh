#! /bin/bash

set -euo pipefail

set -a
source .env
set +a

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

HLS_DIR="$SCRIPT_DIR/../hls"
LOG_FILE="$SCRIPT_DIR/../streaming.log"

touch $LOG_FILE
mkdir -p $HLS_DIR

# Send failure email
send_failure_email() {
  LOG_SNIPPET=$(tail -n 50 "$LOG_FILE")
  /usr/local/bin/aws ses send-email \
    --from "${ALERT_EMAIL}" \
    --destination "ToAddresses=${ALERT_EMAIL}" \
    --message "Subject={Data=Streaming Script Failure,Charset=utf-8},Body={Text={Data=The streaming script failed on $(hostname) at $(date).

Last 50 lines of log:

$LOG_SNIPPET
,Charset=utf-8}}" \
    --region "${REGION}"
}

# Cleanup function to delete the directory if something fails
cleanup_on_error() {
  echo "[start-streaming.sh] ERROR occurred. Cleaning up..."
  rm -rf "$HLS_DIR"
  send_failure_email
  exit 1
}

