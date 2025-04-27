#!/bin/bash

# This upload the generated files to S3
#
# - First make a snapshot by copying all files from hls to hls-tmp
# - Then it copies first all the .ts segments
# - Then it copies the manifest index.m3u8
# - Then it deletes all the files older than 4 minutes
#

source "$(dirname "$0")/shared/shared.sh"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "************************************ [upload-hls-to-s3] started at $(date)"

TMP_DIR="$SCRIPT_DIR/../hls-tmp"

S3_PREFIX="/stream"

EXPIRY_SECONDS=240 # 4 minutes

SLEEP_TIME=45

# Trap ERR and EXIT to trigger cleanup on failure
trap 'cleanup_on_error' ERR

mkdir -p "$HLS_DIR" "$TMP_DIR"

export AWS_MAX_CONCURRENT_REQUESTS=20
export AWS_S3_MULTIPART_THRESHOLD=67108864    # 64MB
export AWS_S3_MULTIPART_CHUNKSIZE=16777216    # 16MB

while true; do

  echo "Waiting $SLEEP_TIME seconds..."
  sleep $SLEEP_TIME

  echo "[*] Cleaning TMP_DIR..."
  rm -rf "$TMP_DIR"/*

  # Check if HLS_DIR is empty
  if [ -z "$(ls -A "$HLS_DIR" 2>/dev/null)" ]; then
    echo "[*] HLS_DIR is empty. Skipping this iteration..."
    continue
  fi

  echo "[*] Copying files from HLS_DIR to TMP_DIR..."
  cp -r "$HLS_DIR/." "$TMP_DIR/"

  echo "[*] Uploading .ts segments to S3..."
  /usr/local/bin/aws s3 sync "$TMP_DIR" "s3://$BUCKET_NAME$S3_PREFIX" \
    --region "$REGION" \
    --exclude "*" --include "*.ts" \
    --only-show-errors \
    --no-guess-mime-type \
    --no-progress \
    --exact-timestamps

  sleep 10

  echo "[*] Uploading manifest (index.m3u8) to S3..."
  /usr/local/bin/aws s3 cp "$TMP_DIR/index.m3u8" "s3://$BUCKET_NAME$S3_PREFIX/index.m3u8" \
    --region "$REGION" \
    --cache-control "no-cache, no-store, must-revalidate" \
    --content-type "application/vnd.apple.mpegurl" \
    --only-show-errors

  CUTOFF=$(date -u -d "-${EXPIRY_SECONDS} seconds" +"%Y-%m-%dT%H:%M:%SZ")

  echo "[*] Deleting files older than $EXPIRY_SECONDS seconds [$BUCKET_NAME] [$REGION] [$CUTOFF]..."
  OBJECTS=$(aws s3api list-objects-v2 \
    --region "$REGION" \
    --bucket "$BUCKET_NAME" \
    --query "Contents[?LastModified<=\`$CUTOFF\`].[Key]" \
    --output text)

  if [ -z "$OBJECTS" ]; then
    echo "No objects older than $EXPIRY_SECONDS seconds to delete."
  else
    BATCH_DELETE_JSON=$(printf '{"Objects":[%s]}' "$(echo "$OBJECTS" | awk '{printf "{\"Key\":\"%s\"},", $0}' | sed 's/,$//')")
    AWS_PAGER="" aws s3api delete-objects \
      --bucket "$BUCKET_NAME" \
      --delete "$BATCH_DELETE_JSON"
  fi

done

# Disable the trap if successful
trap - ERR
