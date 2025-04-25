#!/bin/bash
#
# Add the following line to crontab -e
# @reboot sleep 120 && /<script-path>/start-streaming.sh >> /<script-path>/streaming.log 2>&1
#
# This script handles the 2 scripts:
# - scripts/generate-hls.sh
# - scripts/upload-hls-to-s3.sh
#
# If one of the two script fails, also the other one stop.

set -e

# Add timestamp to logs
exec > >(awk '{ print strftime("[%Y-%m-%d %H:%M:%S]"), "[** START-STREAMING **]", $0; fflush(); }') 2>&1

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

[ -f "$SCRIPT_DIR/streaming.log" ] || touch "$SCRIPT_DIR/streaming.log"
tail -n 500 "$SCRIPT_DIR/streaming.log" > "$SCRIPT_DIR/streaming.log.tmp"
mv "$SCRIPT_DIR/streaming.log.tmp" "$SCRIPT_DIR/streaming.log"

echo "************************************ Started streaming script at $(date)" >> "$SCRIPT_DIR/streaming.log"

mkdir -p "$SCRIPT_DIR/hls"

set -o allexport
source "$SCRIPT_DIR/.env"
set +o allexport

# Cleanup function
cleanup() {
  echo "Sending alert email..."
  send_failure_email
  echo "Cleaning up..."
  pkill -P $$
  # kill $PID1 2>/dev/null || true
  # kill $PID2 2>/dev/null || true
  exit 1
}

send_start_email() {
  if [[ -z "$MAILGUN_API_KEY" ]]; then
    echo "Error: MAILGUN_API_KEY is not set. Email not sent."
    return 1
  fi
  ${SCRIPT_DIR}/scripts/mailgun-send-email.sh "${ALERT_EMAIL}" "Streaming Script Started" "The streaming script started on $(hostname) at $(date)."
}

send_failure_email() {
  if [[ -z "$MAILGUN_API_KEY" ]]; then
    echo "Error: MAILGUN_API_KEY is not set. Email not sent."
    return 1
  fi
  LOG_SNIPPET=$(tail -n 50 "$SCRIPT_DIR/streaming.log")
  ${SCRIPT_DIR}/scripts/mailgun-send-email.sh "${ALERT_EMAIL}" "Streaming Script Failure" "The streaming script failed on $(hostname) at $(date).

Last 50 lines of log:

$LOG_SNIPPET"
}

trap cleanup SIGINT SIGTERM

# Start first script
"$SCRIPT_DIR/scripts/generate-hls.sh" >> "$SCRIPT_DIR/streaming.log" 2>&1 &
PID1=$!

# Wait a bit and check if it exited early
sleep 5
if ! kill -0 $PID1 2>/dev/null; then
  echo "generate-hls.sh exited too early"
  cleanup
fi

# Start second script
"$SCRIPT_DIR/scripts/upload-hls-to-s3.sh" >> "$SCRIPT_DIR/streaming.log" 2>&1 &
PID2=$!

# Wait a bit and check if it exited early
sleep 5
if ! kill -0 $PID2 2>/dev/null; then
  echo "upload-hls-to-s3.sh exited too early"
  cleanup
fi

echo "Both processes started successfully. Sending startup email..."
send_start_email

# Wait for both and trigger cleanup if any fails
wait $PID1 || cleanup
wait $PID2 || cleanup

