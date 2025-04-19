#!/bin/bash

# Explanation:
#     -i is the input option.
#     "0:none" refers to the input device index for the avfoundation capture system (used on macOS).
#
# In "0:none":
#     0 is the index of the video device (camera).
#     none means no audio input.
#
# So:
#     "0:none" uses the first available camera (index 0).
#     "1:none" would use the second camera, and so on.

# Get the Mux stream key from the first argument or prompt the user
if [ -z "$1" ]; then
  read -p "Enter your Mux stream key: " MUX_STREAM_KEY
else
  MUX_STREAM_KEY="$1"
fi

MUX_URL="rtmps://global-live.mux.com:443/app"

# Start streaming video only (no audio)
ffmpeg \
  -f avfoundation -framerate 30 -video_size 1920x1080 -i "0:none" \
  -c:v libx264 -preset veryfast -tune zerolatency \
  -f flv "$MUX_URL/$MUX_STREAM_KEY"

