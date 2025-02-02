resource "aws_s3_bucket" "this" {
  acl    = "private"
  bucket = local.s3_bucket_name

  tags = {
    Name          = local.s3_bucket_name
    ProductDomain = var.product_domain
    Environment   = var.environment
    Description   = var.s3_bucket_description
    ManagedBy     = "terraform"
  }

  logging {
    target_bucket = local.s3_logging_bucket
    target_prefix = "${local.s3_bucket_name}/"
  }

  versioning {
    enabled = var.s3_enable_versioning
  }

  lifecycle_rule {
    enabled                                = var.s3_enable_expiration
    abort_incomplete_multipart_upload_days = 30

    expiration {
      days = var.s3_expiration_days
    }

    noncurrent_version_expiration {
      days = var.s3_expiration_days
    }
  }

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = var.s3_sse_algorithm
      }
    }
  }
}

resource "aws_s3_bucket_public_access_block" "this" {
  bucket = aws_s3_bucket.this.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "this" {
  bucket = aws_s3_bucket.this.id
  policy = data.aws_iam_policy_document.s3_bucket.json
}

resource "aws_cloudwatch_log_group" "this" {
  name              = local.cwl_log_group_name
  retention_in_days = local.cwl_logs_retention_days

  tags = {
    ProductDomain = var.product_domain
    Environment   = var.environment
    Name          = local.cwl_log_group_name
    Description   = "Log group that store session manager logs"
  }
}

resource "aws_ssm_document" "this" {
  name            = var.session_manager_document_name
  document_type   = "Session"
  document_format = "JSON"

  tags = {
    Name          = local.ssm_document_name
    ProductDomain = var.product_domain
    Description   = var.ssm_document_description
    Environment   = var.environment
    ManagedBy     = "terraform"
  }

  content = <<DOC
{
    "schemaVersion": "1.0",
    "description": "${var.ssm_document_description}",
    "sessionType": "Standard_Stream",
    "inputs": {
        "s3BucketName": "${local.s3_bucket_name}",
        "s3KeyPrefix": "${var.s3_bucket_prefix}",
        "s3EncryptionEnabled": true,
        "cloudWatchLogGroupName": "${local.cwl_log_group_name}",
        "cloudWatchEncryptionEnabled": false,
        "cloudWatchStreamingEnabled": true,
        "shellProfile":{
          "linux":"bash"
        }
    }
}
DOC
}

resource "aws_iam_policy" "this" {
  name   = local.iam_policy_name
  policy = data.aws_iam_policy_document.session_manager.json
}
