#! /bin/bash

# This will generate the files that must be uploaded to s3
# The upload is handled from another script
#
# The resolution is set to 640x720
#
# Do not change the manifest file name index.m3u8 since it is the onlyone that
# is not cached by cloudfront, the manifest must be updated in order to index
# the new files when generated.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

VIDEO=/dev/video0
WIDTH=640
HEIGHT=480

# Add timestamp to logs
exec > >(awk '{ print strftime("[%Y-%m-%d %H:%M:%S]"), "[** GENERATE-HLS **]", $0; fflush(); }') 2>&1

# Wait up to 30 seconds for /dev/video* to be available
for i in {1..30}; do
  if [ -e $VIDEO ]; then
    echo "[start-streaming.sh] Camera is available."
    break
  fi
  echo "[start-streaming.sh] Waiting for $VIDEO..."
  sleep 2
done

# If still not available, exit
if [ ! -e $VIDEO ]; then
  echo "[start-streaming.sh] ERROR: $VIDEO not found. Exiting."
  exit 1
fi

echo "[generate-hls.sh] Starting ffmpeg with input: $VIDEO"

ffmpeg -f v4l2 -framerate 30 -video_size ${WIDTH}x${HEIGHT} -i $VIDEO \
  -vf "scale=${WIDTH}:${HEIGHT}" \
  -pix_fmt yuv420p \
  -c:v libx264 \
  -profile:v baseline \
  -preset ultrafast \
  -g 60 \
  -sc_threshold 0 \
  -f hls \
  -hls_time 4 \
  -hls_list_size 10 \
  -hls_flags delete_segments+omit_endlist \
"$SCRIPT_DIR/../hls/index.m3u8"
