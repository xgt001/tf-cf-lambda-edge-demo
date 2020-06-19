data aws_s3_bucket "static_bucket" {
  bucket     = var.distrib_static_bucket_name
  depends_on = [var.distrib_static_bucket_name]
  // Causes funky diffs in creation of the distribution if the bucket is evaluated at runtime
}

resource "aws_s3_bucket" "origin_bucket" {
  acl    = "private"
  bucket = var.distrib_default_bucket_name

  //  Note: Had to disable SSE with KMS since Cloudfront doesn't support it!
  //  https://forums.aws.amazon.com/thread.jspa?threadID=268390
  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }
}

resource "aws_cloudfront_origin_access_identity" "dist_oai" {}

data "aws_iam_policy_document" "default_bucket_s3_policy" {
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.origin_bucket.arn}/*"]

    principals {
      type        = "AWS"
      identifiers = [aws_cloudfront_origin_access_identity.dist_oai.iam_arn]
    }
  }

  statement {
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.origin_bucket.arn]

    principals {
      type        = "AWS"
      identifiers = [aws_cloudfront_origin_access_identity.dist_oai.iam_arn]
    }
  }
}

data "aws_iam_policy_document" "static_bucket_s3_policy" {
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${data.aws_s3_bucket.static_bucket.arn}/*"]

    principals {
      type        = "AWS"
      identifiers = [aws_cloudfront_origin_access_identity.dist_oai.iam_arn]
    }
  }

  statement {
    actions   = ["s3:ListBucket"]
    resources = [data.aws_s3_bucket.static_bucket.arn]

    principals {
      type        = "AWS"
      identifiers = [aws_cloudfront_origin_access_identity.dist_oai.iam_arn]
    }
  }
}

resource "aws_s3_bucket_policy" "default_bucket_access_control" {
  bucket = aws_s3_bucket.origin_bucket.id
  policy = data.aws_iam_policy_document.default_bucket_s3_policy.json
}

resource "aws_s3_bucket_policy" "static_bucket_access_control" {
  bucket = data.aws_s3_bucket.static_bucket.id
  policy = data.aws_iam_policy_document.static_bucket_s3_policy.json
}

locals {
  distribution_alias = join(".", [var.distrib_sub_domain, var.distrib_domain_name])
}

resource "aws_cloudfront_distribution" "distrib" {
  origin {
    domain_name = aws_s3_bucket.origin_bucket.bucket_regional_domain_name
    //faster propagation than global bucket name
    //    and buckets created after 2019 may not work with Cloudfront under the global name
    origin_id = var.distrib_default_bucket_name

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.dist_oai.cloudfront_access_identity_path
    }
  }

  origin {
    //    static origin
    domain_name = data.aws_s3_bucket.static_bucket.bucket_regional_domain_name
    origin_id   = var.distrib_static_bucket_name

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.dist_oai.cloudfront_access_identity_path
    }
  }

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "Let there be light! _until you run into IAM_"
  default_root_object = "index.html"

  aliases = [local.distribution_alias]

  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = var.distrib_default_bucket_name

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "allow-all"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400


    lambda_function_association {
      event_type   = "viewer-request"
      lambda_arn   = aws_lambda_function.cf_distrib_edge_auth.qualified_arn
      include_body = false
    }

  }

  ordered_cache_behavior {
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    path_pattern           = "static/*"
    target_origin_id       = var.distrib_static_bucket_name
    viewer_protocol_policy = "allow-all"
    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }


    lambda_function_association {
      event_type   = "viewer-request"
      lambda_arn   = aws_lambda_function.cf_distrib_edge_auth.qualified_arn
      include_body = false
    }

  }

  price_class = "PriceClass_200"

  restrictions {
    geo_restriction {
      restriction_type = "whitelist"
      locations        = ["DE"]
    }
  }

  viewer_certificate {
    acm_certificate_arn      = var.acm_cert_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1"
  }
  depends_on = [aws_s3_bucket.origin_bucket, data.aws_s3_bucket.static_bucket, aws_lambda_function.cf_distrib_edge_auth]
}

resource "aws_route53_zone" "distrib_pub_zone" {
  name = var.distrib_domain_name
}

resource "aws_route53_record" "distrib_cname" {
  name    = var.distrib_sub_domain
  type    = "A"
  zone_id = aws_route53_zone.distrib_pub_zone.id

  alias {
    name                   = aws_cloudfront_distribution.distrib.domain_name
    zone_id                = aws_cloudfront_distribution.distrib.hosted_zone_id
    evaluate_target_health = false
  }
}