#!/bin/bash

# Stream directly to the hls application on NGINX
RTMP_URL="rtmp://localhost:1935/hls/live"

ffmpeg \
  -f avfoundation -framerate 30 -video_size 1280x720 -pixel_format uyvy422 -i "0:none" \
  -c:v libx264 -preset veryfast -tune zerolatency \
  -f flv "$RTMP_URL"
