#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Add timestamp to logs
exec > >(awk '{ print strftime("[%Y-%m-%d %H:%M:%S]"), "[** UPLOAD-HLS-TO-S3 **]", $0; fflush(); }') 2>&1

set -a
source .env
set +a

inotifywait -m -r -e close_write,create,delete "$SCRIPT_DIR/../hls" --format '%w%f' | while read file; do
  echo "Change detected: $file"
  /usr/local/bin/aws s3 sync "$SCRIPT_DIR/../hls" "s3://$BUCKET_NAME/stream" \
    --region $REGION \
    --delete \
    --exact-timestamps

  # Force no-cache headers for index.m3u8
  if [[ -f "$SCRIPT_DIR/../hls/index.m3u8" ]]; then
    echo "Uploading index.m3u8 with no-cache headers"
    /usr/local/bin/aws s3 cp "$SCRIPT_DIR/../hls/index.m3u8" "s3://$BUCKET_NAME/stream/index.m3u8" \
      --region "$REGION" \
      --cache-control "no-cache, no-store, must-revalidate" \
      --content-type "application/vnd.apple.mpegurl"
  fi

done

