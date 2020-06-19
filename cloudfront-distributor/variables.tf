variable "acm_cert_arn" {
  type = string
}

variable "distrib_domain_name" {
  type = string
}

variable "distrib_sub_domain" {
  type = string
}

variable "distrib_default_bucket_name" {
  type    = string
  default = "cf-distrib-demo-default-bucket"
}

variable "distrib_static_bucket_name" {
  type = string
}