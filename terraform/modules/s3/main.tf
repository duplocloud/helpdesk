locals {
  name_suffix          = var.bucket_name_suffix != "" ? "-${var.bucket_name_suffix}" : ""
  bucket_name          = "ai-studio-${var.account_id}${local.name_suffix}"
  userdata_bucket_name = "ai-studio-userdata-${var.account_id}${local.name_suffix}"
}

resource "aws_s3_bucket" "this" {
  bucket = local.bucket_name
}

resource "aws_s3_bucket" "userdata" {
  bucket = local.userdata_bucket_name
}

resource "aws_s3_bucket_public_access_block" "userdata" {
  bucket                  = aws_s3_bucket.userdata.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "userdata" {
  bucket = aws_s3_bucket.userdata.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "this" {
  bucket                  = aws_s3_bucket.this.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# ── SOC2: versioning ──────────────────────────────────────────────────────────
resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.this.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_versioning" "userdata" {
  bucket = aws_s3_bucket.userdata.id
  versioning_configuration {
    status = "Enabled"
  }
}

# One lifecycle configuration per bucket (S3 allows only one): expire noncurrent versions so versioning
# doesn't grow storage forever, plus the optional current-object expiry on the main bucket.
resource "aws_s3_bucket_lifecycle_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    id     = "expire-noncurrent-versions"
    status = "Enabled"
    filter {}
    noncurrent_version_expiration {
      noncurrent_days = var.noncurrent_version_expiration_days
    }
  }

  dynamic "rule" {
    for_each = var.lifecycle_enabled ? [1] : []
    content {
      id     = "expire-objects"
      status = "Enabled"
      filter {}
      expiration {
        days = var.lifecycle_expiration_days
      }
    }
  }

  depends_on = [aws_s3_bucket_versioning.this]
}

resource "aws_s3_bucket_lifecycle_configuration" "userdata" {
  bucket = aws_s3_bucket.userdata.id

  rule {
    id     = "expire-noncurrent-versions"
    status = "Enabled"
    filter {}
    noncurrent_version_expiration {
      noncurrent_days = var.noncurrent_version_expiration_days
    }
  }

  depends_on = [aws_s3_bucket_versioning.userdata]
}

moved {
  from = aws_s3_bucket_lifecycle_configuration.this[0]
  to   = aws_s3_bucket_lifecycle_configuration.this
}

# ── SOC2: HTTPS-only ──────────────────────────────────────────────────────────
data "aws_iam_policy_document" "https_only" {
  for_each = {
    this     = aws_s3_bucket.this.arn
    userdata = aws_s3_bucket.userdata.arn
  }

  statement {
    sid     = "DenyInsecureTransport"
    effect  = "Deny"
    actions = ["s3:*"]
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    resources = [each.value, "${each.value}/*"]
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "this" {
  bucket = aws_s3_bucket.this.id
  policy = data.aws_iam_policy_document.https_only["this"].json

  depends_on = [aws_s3_bucket_public_access_block.this]
}

resource "aws_s3_bucket_policy" "userdata" {
  bucket = aws_s3_bucket.userdata.id
  policy = data.aws_iam_policy_document.https_only["userdata"].json

  depends_on = [aws_s3_bucket_public_access_block.userdata]
}
