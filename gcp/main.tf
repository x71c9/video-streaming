terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }

  backend "gcs" {
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

variable "project_id" {
  type = string
  description = "The GCP project id"
}

variable "stream_bucket_name" {
  type = string
  description = "name of the bucket where there will be stored the stream files"
}

variable "region" {
  type    = string
}

variable "allowed_origin" {
  type        = string
  description = "CORS allowed origin (your frontend website URL)"
}

variable "alert_email" {
  type = string
  description = "Email for the alerts"
}

resource "google_storage_bucket" "stream_content_bucket" {
  name          = var.stream_bucket_name
  location      = var.region
  force_destroy = true
  uniform_bucket_level_access = true

  cors {
    origin          = [var.allowed_origin]
    method          = ["GET", "HEAD"]
    response_header = ["Content-Type"]
    max_age_seconds = 3600
  }
}

resource "google_storage_bucket_iam_member" "public_read" {
  bucket = google_storage_bucket.stream_content_bucket.name
  role   = "roles/storage.objectViewer"
  member = "allUsers"
}

resource "google_service_account" "uploader" {
  account_id   = "hls-uploader"
  display_name = "HLS Uploader"
}

resource "google_storage_bucket_iam_member" "uploader_write" {
  bucket = google_storage_bucket.stream_content_bucket.name
  role   = "roles/storage.objectCreator"
  member = "serviceAccount:${google_service_account.uploader.email}"
}

resource "null_resource" "generate_uploader_key" {
  provisioner "local-exec" {
    command = <<EOT
      gcloud iam service-accounts keys create ./camerahost/video-streaming-uploader-credentials.json \
        --iam-account=${google_service_account.uploader.email} \
        --project=${var.project_id}
    EOT
  }

  depends_on = [
    google_service_account.uploader
  ]
}


output "uploader_service_account_email" {
  value = google_service_account.uploader.email
}

output "uploader_key_path" {
  value = "./camerahost/video-streaming-uploader-credentials.json"
  description = "Path to the generated service account key file"
}
