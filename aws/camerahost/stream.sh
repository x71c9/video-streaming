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

init_log_file(){
  touch $LOG_FILE_PATH
  truncate -s 0 $LOG_FILE_PATH
  echo "------------ $(date): Init Log Truncated" >> $LOG_FILE_PATH
}

init_directories(){
  rm -rf "$HLS_DIR" "$SNAPSHOT_TMP_DIR"
  mkdir -p "$HLS_DIR" "$SNAPSHOT_TMP_DIR"
}

send_failure_email() {
  echo "************ [$(date)] send_failure_email"
  if [ -n "${ALERT_EMAIL:-}" ]; then
    LOG_SNIPPET=$(tail -n 50 "$LOG_FILE_PATH")
    /usr/local/bin/aws ses send-email \
      --from "${ALERT_EMAIL}" \
      --destination "ToAddresses=${ALERT_EMAIL}" \
      --message "Subject={Data=Streaming Script Failure,Charset=utf-8},Body={Text={Data=The streaming script failed on $(hostname) at $(date).

  Last 50 lines of log:

  $LOG_SNIPPET
  ,Charset=utf-8}}" \
      --region "${REGION}"
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
    -hls_segment_filename "$HLS_DIR/segment_%Y%m%d_%H%M%S.ts" \
    "$HLS_DIR/index.m3u8" &
  FFMPEG_PID=$!
}

delete_old_segments(){

  CUTOFF=$(date -u -d "-${BUCKET_OBJECTS_EXPIRY_SECONDS} seconds" +"%Y-%m-%dT%H:%M:%SZ")

  echo "[*] Deleting files older than $BUCKET_OBJECTS_EXPIRY_SECONDS seconds [$BUCKET_NAME] [$REGION] [$CUTOFF]..."
  echo "/usr/local/bin/aws s3api list-objects-v2 \
    --region \"$REGION\" \
    --bucket \"$BUCKET_NAME\" \
    --query \"Contents[?LastModified<=\`$CUTOFF\`].[Key]\" \
    --no-paginate \
    --output text"
  OBJECTS=$(/usr/local/bin/aws s3api list-objects-v2 \
    --region "$REGION" \
    --bucket "$BUCKET_NAME" \
    --query "Contents[?LastModified<=\`$CUTOFF\`].[Key]" \
    --no-paginate \
    --output text)
  echo $OBJECTS
  if [ -z "$OBJECTS" ]; then
    echo "No objects older than $BUCKET_OBJECTS_EXPIRY_SECONDS seconds to delete."
  else
    BATCH_DELETE_JSON=$(printf '{"Objects":[%s]}' "$(echo "$OBJECTS" | awk '{printf "{\"Key\":\"%s\"},", $0}' | sed 's/,$//')")
    echo "/usr/local/bin/aws s3api delete-objects \
      --bucket \"$BUCKET_NAME\" \
      --delete \"$BATCH_DELETE_JSON\""
    AWS_PAGER="" /usr/local/bin/aws s3api delete-objects \
      --bucket "$BUCKET_NAME" \
      --delete "$BATCH_DELETE_JSON"
  fi

}

start_upload(){

  echo "************ [$(date)] start_upload"

  check_video

  export AWS_MAX_CONCURRENT_REQUESTS=20
  export AWS_S3_MULTIPART_THRESHOLD=67108864    # 64MB
  export AWS_S3_MULTIPART_CHUNKSIZE=16777216    # 16MB

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
    cp -r "$HLS_DIR/." "$SNAPSHOT_TMP_DIR/"

    echo "[*] Uploading .ts segments to S3..."
    /usr/local/bin/aws s3 sync "$SNAPSHOT_TMP_DIR" "s3://$BUCKET_NAME$BUCKET_STREAM_PREFIX" \
      --region "$REGION" \
      --exclude "*" --include "*.ts" \
      --only-show-errors \
      --no-guess-mime-type \
      --no-progress \
      --exact-timestamps

    echo "[*] $(date) Segments uploaded to S3"

    sleep 10

    echo "[*] Uploading manifest (index.m3u8) to S3..."
    /usr/local/bin/aws s3 cp "$SNAPSHOT_TMP_DIR/index.m3u8" "s3://$BUCKET_NAME$BUCKET_STREAM_PREFIX/index.m3u8" \
      --region "$REGION" \
      --cache-control "no-cache, no-store, must-revalidate" \
      --content-type "application/vnd.apple.mpegurl" \
      --only-show-errors

    echo "[*] $(date) Manifest uploaded to S3"

    delete_old_segments &

  done

}

truncate_logs(){
  while true; do
    sleep 86400
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
