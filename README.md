# video streaming demos

## Demo 0 [AWS]

Parts:

1. Generate HLS file with ffmpeg in local machine from a camera /dev/video0
2. Upload HLS files to S3 on AWS
3. Use Cloudfront for security and caching files

### How to make it work



## Demo 1 [NGINX]

The demo 2 create a streaming server with docker and nginx image. The
configuration of the server is in `nginx.conf`. This configuration file
will be overwritten by the one in the cotainer since it is set as volume.

1. Run `docker-nginx.sh` to start the docker contianer with the server.
2. Run `ffmpeg-to-nginx.sh` to start streaming the camera feed to the nginx
server.

The script sends only the video stream and not the audio. More info in the
script.

The server is gonna serve the stream on localhost:

```bash
http://localhost:8080/hls/live/index.m3u8
```

There is an index.html file to see the streaming.
