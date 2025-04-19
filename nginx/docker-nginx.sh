#! /bin/bash

docker run -d --platform linux/amd64 \
  --name rtmp-server \
  -p 1935:1935 -p 8080:80 \
  -v "$PWD/nginx.conf":/etc/nginx/nginx.conf \
  -v "$PWD/data":/opt/data \
  alfg/nginx-rtmp

