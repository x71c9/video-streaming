#!/bin/bash

set -a
source .env
set +a

BUCKET_NAME="nbl7-video-streaming-prod-carbon-streaming"
REGION="eu-south-1"
DEST_PATH="stream"
SRC_DIR="./hls"

inotifywait -m -r -e close_write,create,delete "$SRC_DIR" --format '%w%f' | while read file; do
  echo "Change detected: $file"
  aws s3 sync "$SRC_DIR" "s3://$BUCKET_NAME/$DEST_PATH" \
    --region $REGION \
    --delete \
    --exact-timestamps
done

