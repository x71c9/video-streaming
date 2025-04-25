# video streaming demos

## Demo 0 [AWS]

Parts:

1. Generate HLS file with ffmpeg in local machine from a camera /dev/video0
2. Upload HLS files to S3 on AWS
3. Use Cloudfront for security and caching files, it also reduce egress costs.

### How to make it work

#### On the local machine with terraform installed

Be sure you are logged on an AWS account, meaning you have the following
variables set up:
```bash
AWS_ACCESS_KEY_ID=
AWS_SECRET_ACCESS_KEY=
```

Then:
```bash
cd ./aws/

./terraform-apply.sh
```

After all the resources are deployed generate the `.env` file with:

```bash
bash generate-dotenv.sh
```

This will generate the `.env` file inside `./camerahost/.env`.\
In `./camerahost` there are all the files needed by the host of the camera to
generate and upload the files to AWS. You can:

```bash
scp -pr camerahost/. x71c9@192.168.1.40:/home/<user>/streaming/
```

#### On the host of the camera

The host should have the following libraries:
```
awk
inotifywait
aws
```
Not the AWS cli under `/usr/local/bin/aws`.

The update the Cron jobs:
```bash
crontab -e
```

Add the following line:
```
@reboot sleep 120 && /home/<user>/streaming/start-streaming.sh >> /home/<user>/streaming/streaming.log 2>&1
```

Reboot the system:
```
sudo reboot -h now
```

#### On the local machine with terraform installed

You can generate and index.html file for watching the stream with:

```bash
bash generate-html.sh
```

You can destroy everything with:

```bash
./terraform-destroy.sh
```

## Demo 2 [GCP]

Parts:

1. Generate HLS file with ffmpeg in local machine from a camera /dev/video0
2. Upload HLS files to a Google Cloud Storage Bucket
3. For production you might want to add a LoadBalancer/CDN that cache the files
and also reduce the egress costs, however the LoadBalancer has a fixed cost of
18€/month.
4. Unlike AWS, in order to generate budget alert on GCP terraform must invoke
the `billingbudgets.googleapis.com` API. Apprently this API can be called only
by a Service Account with specific permission, and not an avarage user even with
Admin permission. Becasue of this it has been decided to remove the budget alert
component in GCP demo.

### How to make it work

#### On the local machine with terraform installed

Be sure you are logged on an GCP account, with:
```bash
gcloud auth login
```

Then:
```bash
cd ./gcp/

./terraform-apply.sh
```

After all the resources are deployed generate the `.env` file with:

```bash
bash generate-dotenv.sh
```

This will generate the `.env` file inside `./camerahost/.env`.\
In `./camerahost` there are all the files needed by the host of the camera to
generate and upload the files to AWS. You can:

```bash
scp -pr camerahost/. x71c9@192.168.1.40:/home/<user>/streaming/
```
## Demo 3 [NGINX]

The demo 3 create a streaming server with docker and nginx image. The
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
