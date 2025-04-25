#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

STAGING_DIR="$SCRIPT_DIR/../hls-staging"
BUCKET_PATH="gs://$BUCKET_NAME/streaming"

# Add timestamp to logs
exec > >(awk '{ print strftime("[%Y-%m-%d %H:%M:%S]"), "[** UPLOAD-HLS-TO-S3 **]", $0; fflush(); }') 2>&1

set -a
source .env
set +a

# Set the GOOGLE_APPLICATION_CREDENTIALS environment variable to the path of your credentials file
export GOOGLE_APPLICATION_CREDENTIALS="$SCRIPT_DIR/video-streaming-uploader-credentials.json"
gcloud auth activate-service-account --key-file="$GOOGLE_APPLICATION_CREDENTIALS"
echo "Using credentials from: $GOOGLE_APPLICATION_CREDENTIALS"

inotifywait -m -r -e close_write,create,delete "$SCRIPT_DIR/../hls" --format '%w%f' | while read file; do
  echo "Change detected: $file"

  cp -rfa "$SCRIPT_DIR/../hls/." "$STAGING_DIR"

  gcloud storage rsync --exclude "index.m3u8" --delete-unmatched-destination-objects -r "$STAGING_DIR/." $BUCKET_PATH

  gcloud storage cp --cache-control="no-store" "$STAGING_DIR/index.m3u8" "$BUCKET_PATH/index.m3u8"

  rm -rf "$STAGING_DIR/"*

done

