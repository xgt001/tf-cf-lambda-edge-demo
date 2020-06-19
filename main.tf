resource "aws_s3_bucket" "static_bucket" {
  bucket = "your-unique-static-bucket-if-not-created"
  acl    = "private"

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }
}

module "cf_distrib" {
  source                     = "./cloudfront-distributor/"
  acm_cert_arn               = "arn:aws:acm:us-east-1:foo:certificate/bar"
  distrib_sub_domain         = "secure-cf-demo"
  distrib_domain_name        = "your_cf_domain"
  distrib_static_bucket_name = "your-unique-static-bucket"
//
//  distrib_default_bucket_name = "your-unique-default-bucket"
//  distrib_static_bucket_name = aws_s3_bucket.static_bucket.bucket
}



