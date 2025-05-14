#!/bin/bash

# Generates the HLS file for the streaming with `start_ffmpeg`
#
# Upload the generated files to S3 with `start_upload`:
#
# - First make a snapshot by copying all files from hls to hls-tmp
# - Then it copies first all the .ts segments
# - Then it copies the manifest index.m3u8
# - Then it deletes all the files older than 4 minutes
#
# Do not change the manifest file name `index.m3u8` since it is the onlyone that
# is not cached by Cloudfront
#

DEBUG=false

if [ "$DEBUG" = true ]; then
  set -euxo pipefail
else
  set -euo pipefail
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

set -a
source $SCRIPT_DIR/.env
set +a

LOG_FILE_PATH="$SCRIPT_DIR/stream.log"

HLS_DIR="$SCRIPT_DIR/hls"
SNAPSHOT_TMP_DIR="$SCRIPT_DIR/hls-tmp"

VIDEO=/dev/video0
VIDEO_WIDTH=640
VIDEO_HEIGHT=480
VIDEO_FONT_SIZE=$(( VIDEO_HEIGHT / 53 ))

BUCKET_STREAM_PREFIX="/stream"
BUCKET_OBJECTS_EXPIRY_SECONDS=480
UPLOAD_INTERVAL_SECONDS=45
BUCKET_PATH="gs://$BUCKET_NAME${BUCKET_STREAM_PREFIX}"

BUCKET_OBJECTS_EXPIRY_SECONDS=480
UPLOAD_INTERVAL_SECONDS=45

export GOOGLE_APPLICATION_CREDENTIALS="$SCRIPT_DIR/video-streaming-uploader-credentials.json"
gcloud auth activate-service-account --key-file="$GOOGLE_APPLICATION_CREDENTIALS"
echo "Using credentials from: $GOOGLE_APPLICATION_CREDENTIALS"

init_log_file(){
  touch $LOG_FILE_PATH
  truncate -s 0 $LOG_FILE_PATH
  echo "********************** [$(date)] Init Log Truncated" >> $LOG_FILE_PATH
}

init_directories(){
  rm -rf "$HLS_DIR" "$SNAPSHOT_TMP_DIR"
  mkdir -p "$HLS_DIR" "$SNAPSHOT_TMP_DIR"
}

mailgun_send(){
  MAILGUN_API_BASE="https://api.eu.mailgun.net/v3/${MAILGUN_DOMAIN}"
  FROM="Mailgun <mailgun@${MAILGUN_DOMAIN}>"
  TO=$1
  SUBJECT=$2
  TEXT=$3
  curl -s --user "api:${MAILGUN_API_KEY}" \
      "${MAILGUN_API_BASE}/messages" \
      -F from="${FROM}" \
      -F to="${TO}" \
      -F subject="${SUBJECT}" \
      -F text="${TEXT}"
}

send_failure_email() {
  echo "************ [$(date)] send_failure_email"
  if [ -n "${ALERT_EMAIL:-}" ]; then
    LOG_SNIPPET=$(tail -n 50 "$LOG_FILE_PATH")

    mailgun_send $ALERT_EMAIL "Streaming Script Failure" "The streaming script failed on $(hostname) at $(date).

Last 50 lines of log:

$LOG_SNIPPET
,Charset=utf-8}}"
  fi
}

check_video(){
  echo "************ [$(date)] check_video"
  echo "[stream.sh] Waiting for camera device $VIDEO..."
  if ! timeout 30 bash -c "until [ -e $VIDEO ]; do sleep 1; done"; then
    echo "[stream.sh] ERROR: Camera not found after 30s"
    exit 1
  fi
}

FFMPEG_PID=""

cleanup_on_error() {
  echo "************ [$(date)] cleanup_on_error"
  if [ -n "$FFMPEG_PID" ]; then
    echo "[stream.sh] Killing ffmpeg with PID $FFMPEG_PID..."
    kill "$FFMPEG_PID" 2>/dev/null || true
  fi
  echo "[stream.sh] ERROR occurred. Cleaning up..."
  rm -rf "$HLS_DIR"
  send_failure_email
  exit 1
}

start_ffmpeg(){
  echo "************ [$(date)] start_ffmpeg"
  ffmpeg -f v4l2 -framerate 30 -video_size ${VIDEO_WIDTH}x${VIDEO_HEIGHT} -i $VIDEO \
    -vf "drawtext=font='monospace':text='%{localtime\:%Y-%m-%d %H\\\\\:%M\\\\\:%S}':\
  fontcolor=white:fontsize=$VIDEO_FONT_SIZE:x=w-text_w:y=h-text_h:box=1:boxcolor=black@1,scale=${VIDEO_WIDTH}:${VIDEO_HEIGHT}" \
    -pix_fmt yuv420p \
    -c:v libx264 \
    -profile:v baseline \
    -preset ultrafast \
    -g 60 \
    -sc_threshold 0 \
    -f hls \
    -hls_time 4 \
    -hls_list_size 30 \
    -hls_flags delete_segments+omit_endlist+independent_segments \
    -strftime 1 \
    -loglevel error \
    -hls_segment_filename "$HLS_DIR/segment_%Y%m%d_%H%M%S_%03d.ts" \
    "$HLS_DIR/index.m3u8" &
  FFMPEG_PID=$!
}

delete_old_segments(){

  CUTOFF_DATE=$(date -u -d "@$(( $(date +%s) - BUCKET_OBJECTS_EXPIRY_SECONDS ))" +"%Y-%m-%dT%H:%M:%SZ")

  echo "[*] Deleting files older than $BUCKET_OBJECTS_EXPIRY_SECONDS seconds [$BUCKET_NAME] [$REGION] [$CUTOFF_DATE]..."

  # === Step 1: List all objects ===
  echo "[*] Fetching object list..."
  OBJECTS_JSON=$(gcloud storage objects list "gs://$BUCKET_NAME" --format=json)
  echo "[*] Raw list response:"
  echo "$OBJECTS_JSON" | jq '.'

  # === Step 2: Filter old objects ===
  echo "[*] Filtering objects older than cutoff time..."
  OLD_OBJECTS=$(echo "$OBJECTS_JSON" | jq -r --arg cutoff "$CUTOFF_DATE" '.[] | select(.update < $cutoff) | .name')

  if [ -z "$OLD_OBJECTS" ]; then
    echo "[*] No objects older than $CUTOFF_DATE found."
    exit 0
  fi

  echo "[*] Objects to delete:"
  echo "$OLD_OBJECTS"

  # === Step 3: Delete filtered objects ===
  while IFS= read -r OBJECT_NAME; do
    echo "[*] Deleting: gs://$BUCKET_NAME/$OBJECT_NAME"
    gcloud storage objects delete "gs://$BUCKET_NAME/$OBJECT_NAME" --quiet
  done <<< "$OLD_OBJECTS"

}

start_upload(){

  echo "************ [$(date)] start_upload"

  check_video

  while true; do

    echo "************ [$(date)] Waiting $UPLOAD_INTERVAL_SECONDS seconds..."
    sleep $UPLOAD_INTERVAL_SECONDS

    echo "[*] Cleaning SNAPSHOT_TMP_DIR..."
    rm -rf "$SNAPSHOT_TMP_DIR"/*

    # Check if HLS_DIR is empty
    if [ -z "$(ls -A "$HLS_DIR" 2>/dev/null)" ]; then
      echo "[*] HLS_DIR is empty. Skipping this iteration..."
      continue
    fi

    echo "[*] Copying files from HLS_DIR to SNAPSHOT_TMP_DIR..."
    # cp -r "$HLS_DIR/." "$SNAPSHOT_TMP_DIR/"
    for file in "$HLS_DIR"/*; do
      if [ -f "$file" ]; then
        cp "$file" "$SNAPSHOT_TMP_DIR/" & # Run in background, therefor in parllel
      else
        echo "[!] Warning $(date): Missing file: $file"
      fi
    done

    echo "[*] Uploading .ts segments to the bucket..."
    gcloud storage rsync --exclude "index.m3u8" --delete-unmatched-destination-objects -r "$SNAPSHOT_TMP_DIR/." $BUCKET_PATH
    echo "[*] $(date) Segments uploaded to the bucket"

    sleep 10

    echo "[*] Uploading manifest (index.m3u8) to the bucket..."
    gcloud storage cp --cache-control="no-store" "$SNAPSHOT_TMP_DIR/index.m3u8" "$BUCKET_PATH/index.m3u8"
    echo "[*] $(date) Manifest uploaded to the bucket"

    delete_old_segments &

  done

}

truncate_logs(){
  while true; do
    sleep 864000 # 10 gg
    truncate -s 0 $LOG_FILE_PATH
    echo "------------ $(date): Daily Log Truncated" >> $LOG_FILE_PATH
  done
}

# --------------------------
# -------- EXECUTE ---------
# --------------------------

echo "************************************ [STREAM] started at $(date)"

init_directories

init_log_file

start_ffmpeg &
PID1=$!

truncate_logs &
PID2=$!

start_upload &
PID3=$!

wait $PID1 || cleanup_on_error
wait $PID2 || cleanup_on_error
wait $PID3 || cleanup_on_error
