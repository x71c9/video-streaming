terraform {
  backend "s3" {}
}

provider "aws" {
  region = var.region
}

variable "region" {
  type    = string
}

variable "allowed_origin" {
  type        = string
  description = "CORS allowed origin (your frontend website URL)"
}

variable "stream_bucket_name" {
  type = string
  description = "Name of the bucket where there will be stored the stream files"
}

variable "environment" {
  type = string
  description = "Environment name [dev/staging/prod]"
}

variable "monthly_budget_usd" {
  type = string
  description = "Amount for the budget in number USD"
}

variable "budget_alert_email" {
  type = string
  description = "Email for the alert of the budget"
}


resource "aws_s3_bucket" "carbon_stream_bucket" {
  bucket = "${var.stream_bucket_name}"
  lifecycle {
    prevent_destroy = false
  }
}

resource "aws_s3_bucket_policy" "allow_cloudfront_only" {
  bucket = aws_s3_bucket.carbon_stream_bucket.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowCloudFrontServicePrincipal"
        Effect    = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.carbon_stream_bucket.arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.carbon_stream_distribution.arn
          }
        }
      }
    ]
  })
}

resource "aws_s3_bucket_cors_configuration" "cors" {
  bucket = aws_s3_bucket.carbon_stream_bucket.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "HEAD"]
    allowed_origins = [var.allowed_origin]
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}

resource "aws_cloudfront_origin_access_control" "oac" {
  name                              = "${var.environment}-carbon-s3-oac"
  description                       = "OAC for S3 video bucket"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "carbon_stream_distribution" {
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "Video streaming CDN"
  default_root_object = "stream/index.m3u8"

  origin {
    domain_name = aws_s3_bucket.carbon_stream_bucket.bucket_regional_domain_name
    origin_id   = "${var.environment}-carbon-s3-video-origin"

    origin_access_control_id = aws_cloudfront_origin_access_control.oac.id
  }

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "${var.environment}-carbon-s3-video-origin"
    viewer_protocol_policy = "redirect-to-https"

    forwarded_values {
      query_string = false
      headers      = [] # <= Don't forward headers unless necessary
      cookies {
        forward = "none"
      }
    }

    compress     = true

    min_ttl     = 3600 # 1h
    default_ttl = 3600
    max_ttl     = 3600
  }

  # Do not cache the manifest index.m3u8
  ordered_cache_behavior {
    path_pattern     = "/stream/index.m3u8"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "${var.environment}-carbon-s3-video-origin"
    viewer_protocol_policy = "redirect-to-https"

    forwarded_values {
      query_string = false
      headers      = ["Origin"]
      cookies {
        forward = "none"
      }
    }

    min_ttl     = 0
    default_ttl = 0
    max_ttl     = 0

    compress = true
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

resource "aws_iam_user" "s3_upload_user" {
  name = "${var.environment}-carbon-s3-upload-user"
}

resource "aws_iam_user_policy" "s3_upload_policy" {
  name = "${var.environment}-carbon-s3-upload-policy"
  user = aws_iam_user.s3_upload_user.name

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "s3:ListBucket"
        ],
        Resource = aws_s3_bucket.carbon_stream_bucket.arn
      },
      {
        Effect = "Allow",
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ],
        Resource = "${aws_s3_bucket.carbon_stream_bucket.arn}/*"
      }
    ]
  })
}

resource "aws_iam_access_key" "s3_upload_user_key" {
  user = aws_iam_user.s3_upload_user.name
}

resource "aws_budgets_budget" "monthly_budget" {
  name              = "${var.environment}-monthly-budget"
  budget_type       = "COST"
  limit_amount      = "${var.monthly_budget_usd}"
  limit_unit        = "USD"
  time_unit         = "MONTHLY"

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = ["${var.budget_alert_email}"]
  }
}

output "cloudfront_url" {
  value = aws_cloudfront_distribution.carbon_stream_distribution.domain_name
}

output "s3_upload_aws_access_key_id" {
  value       = aws_iam_access_key.s3_upload_user_key.id
  description = "Access Key ID for the S3 upload user"
  sensitive   = true
}

output "s3_upload_aws_secret_access_key" {
  value       = aws_iam_access_key.s3_upload_user_key.secret
  description = "Secret Access Key for the S3 upload user"
  sensitive   = true
}
