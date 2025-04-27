#! /bin/bash

# This generates the HLS file for the streaming
#
# The resolution is set to 640x480
#
# Do not change the manifest file name index.m3u8 since it is the onlyone that
# is not cached by Cloudfront
#

source "$(dirname "$0")/shared/shared.sh"

echo "************************************ [generate-hls] started at $(date)"

VIDEO=/dev/video0
WIDTH=640
HEIGHT=480
FONT_SIZE=$(( HEIGHT / 53 ))

rm -rf "$HLS_DIR"
mkdir -p "$HLS_DIR"

# Trap ERR and EXIT to trigger cleanup on failure
trap 'cleanup_on_error' ERR

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
  -vf "drawtext=font='monospace':text='%{localtime\:%Y-%m-%d %H\\\\\:%M\\\\\:%S}':\
fontcolor=white:fontsize=$FONT_SIZE:x=w-text_w:y=h-text_h:box=1:boxcolor=black@1,scale=${WIDTH}:${HEIGHT}" \
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
  -hls_segment_filename "$SCRIPT_DIR/../hls/segment_%Y%m%d_%H%M%S.ts" \
  "$SCRIPT_DIR/../hls/index.m3u8"

# Disable the trap if successful
trap - ERR
