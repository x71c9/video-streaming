#! /bin/bash

# This will generate the files that must be uploaded to s3
# The upload is handled from another script
#
# The resolution is set to 1280x720
#
# Do not change the manifest file name index.m3u8 since it is the onlyone that
# is not cached by cloudfront, the manifest must be updated in order to index
# the new files when generated.

ffmpeg -f v4l2 -i /dev/video0 \
  -vf "scale=1280:720" \
  -pix_fmt yuv420p \
  -c:v libx264 -profile:v baseline -preset veryfast -g 60 -sc_threshold 0 \
  -f hls \
  -hls_time 4 \
  -hls_list_size 10 \
  -hls_flags delete_segments+omit_endlist \
  ./hls/index.m3u8

