# video streaming demos

## Demo 0 [AWS]

Parts:

1. Generate HLS file with ffmpeg in local machine
2. Upload HLS files to S3 on AWS
3. Use Cloudfront (for security reason, not allowing s3 to be publicly expose)

## Demo 1 [MUX]

Using the https://mux.com server in order to stream.

1. Create a Live Stream in mux.com
2. Get the "Stream Key" from the Live Stream
3. Set the "Stream Key" in the `ffmpeg-to-mux.sh` script

The script sends only the video stream and not the audio. More info in the
script.

## Demo 2 [NGINX]

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
