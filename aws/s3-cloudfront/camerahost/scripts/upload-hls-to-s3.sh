#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Add timestamp to logs
exec > >(awk '{ print strftime("[%Y-%m-%d %H:%M:%S]"), $0; fflush(); }') 2>&1

set -a
source .env
set +a

inotifywait -m -r -e close_write,create,delete "$SCRIPT_DIR/../hls" --format '%w%f' | while read file; do
  echo "Change detected: $file"
  /usr/local/bin/aws s3 sync "$SCRIPT_DIR/../hls" "s3://$BUCKET_NAME/stream" \
    --region $REGION \
    --delete \
    --exact-timestamps
done

