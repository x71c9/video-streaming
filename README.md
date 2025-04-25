# Video Streaming Demos

This repository contains a series of demos for low-cost, resilient video streaming setups using various cloud providers. The goal is to stream live video from a local camera (e.g., `/dev/video0`) to the internet using HTTP Live Streaming (HLS), while keeping costs below €5/month per camera.

Each demo shows a different deployment approach—leveraging AWS, Google Cloud Platform (GCP), or NGINX locally—aimed at balancing performance, reliability, and affordability. These setups are ideal for self-hosted surveillance, public video feeds, or experimental broadcasting.

---

## Demo 0 – AWS-based Streaming

**Overview**:
- Capture video from `/dev/video0` using `ffmpeg`
- Generate and upload HLS segments to an S3 bucket
- Serve content via CloudFront (for caching, HTTPS, and reduced egress costs)

### Setup Instructions

#### 1. On the Local Machine

Ensure you have Terraform installed and are authenticated with AWS:

```bash
export AWS_ACCESS_KEY_ID=...
export AWS_SECRET_ACCESS_KEY=...
export AWS_PROFILE=...
```

Then run from the root of this repo:

```bash
cd ./aws/
./terraform-apply.sh
```

After deployment, generate the `.env` file:

```bash
bash generate-dotenv.sh
```

This creates `.env` inside `./camerahost/`. Transfer files to the camera host:

```bash
scp -pr camerahost/. <user>@<camera-host-ip>:/home/<user>/streaming-aws/
```

#### 2. On the Camera Host

Required tools:

```
awk
inotifywait
aws
```

> Make sure the AWS CLI is installed in `/usr/local/bin/aws`.

Set up the cron job:

```bash
crontab -e
```

Add the following line:

```bash
@reboot sleep 120 && /home/<user>/streaming-aws/start-streaming.sh >> /home/<user>/streaming-aws/streaming.log 2>&1
```

Reboot the system:

```bash
sudo reboot -h now
```

#### 3. (Optional) On the Local Machine

To generate an `index.html` for viewing the stream:

```bash
bash generate-html.sh
```

To tear down the infrastructure:

```bash
./terraform-destroy.sh
```

---

## Demo 2 – GCP-based Streaming

**Overview**:
- Capture video using `ffmpeg`
- Upload HLS segments to a GCP Cloud Storage bucket
- CDN/Load Balancer (optional in production, costs ~€18/month) [Not implemented]
- Budget alerts were excluded due to GCP permission limitations on billing APIs

### Setup Instructions

#### 1. On the Local Machine

Authenticate with GCP:

```bash
gcloud auth login
```

Then run from the root of this repo:

```bash
cd ./gcp/
./terraform-apply.sh
```
The `terraform-apply.sh` also generate the
`video-streaming-uploader-credentials.json` needed by the script
`./camerahost/scripts/upload-hls-to-s3.ts` in order to run.

The credentials contains the token for the service account to upload file on the
bucket.

Generate the `.env` file:

```bash
bash generate-dotenv.sh
```

Optionally, add Mailgun credentials for email notifications:

```bash
MAILGUN_API_KEY=
MAILGUN_DOMAIN=
```

Transfer camera host files:

```bash
scp -pr camerahost/. <user>@<camera-host-ip>:/home/<user>/streaming-gcp/
```

#### 2. On the Camera Host

Required tools:

```
awk
inotifywait
aws
```

Set up the cron job:

```bash
crontab -e
```

Add:

```bash
@reboot sleep 120 && /home/<user>/streaming-gcp/start-streaming.sh >> /home/<user>/streaming-gcp/streaming.log 2>&1
```

Reboot:

```bash
sudo reboot -h now
```

#### 3. (Optional) On the Local Machine

Generate a viewer HTML page:

```bash
bash generate-html.sh
```

Destroy infrastructure:

```bash
./terraform-destroy.sh
```

---

## Demo 3 – Local Streaming with Docker + NGINX

**Overview**:
- Run a local streaming server using Docker and NGINX
- Push the video stream (no audio) to the server via `ffmpeg`

### Usage

1. Start the NGINX container:

```bash
./docker-nginx.sh
```

2. Start streaming the feed to NGINX:

```bash
./ffmpeg-to-nginx.sh
```

> The `nginx.conf` inside the container will overwrite the local one via a volume mount.

### View the Stream

Stream is available at:

```bash
http://localhost:8080/hls/live/index.m3u8
```

Open `index.html` locally in a browser to view the stream.

