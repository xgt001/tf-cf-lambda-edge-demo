## Objective

Demonstrate asset distribution over CloudFront with Terraform with geo restriction, s3 bucket encryption and basic auth powered by Lambda@Edge.

## Applying 

`terraform apply` should do the trick.

### Manual bits (heresy)
* For my personal account, since my ACM certificate is tied to a pre-created route53 hosted zone, I have to copy the CNAME to the _actual_ Route53 zone which is an exact replica.  
* Copy the assets in the `assets/spa` folder to the default bucket for the SPA 
* Copy the default kitty in `assets/static/` to demo the static bucket 

## Cleaning Up

Run `terraform destroy` after removing all the bucket objects. If you do _enable_ versioning, then you can use the little helper script attached to clean all the versions quickly.

Note: This by default will not work on Lambda@Edge and you will have to manually clean it up  due to the following limitation from AWS in deleting Lambda@Edge functions.
 ```    
 An error occurred when deleting your function: Lambda was unable to delete arn:aws:lambda:us-east-1:blah:function:lambda_basic_auth:3 because it is a replicated function. Please see our documentation for Deleting Lambda@Edge Functions and Replicas.
```
 To clean up the state feel free to execute the below state management command and then remove it from the console about after 30 minutes from running `terraform destroy` 


`terraform state rm module.cf_distrib.aws_lambda_function.cf_distrib_edge_auth`

## Bugs
Terraform plan after making code changes to the Lambda can cause a diff in plan due to dynamic state evaluation issues with CloudFront Lambda attachment. This unfortunately is due to an upstream bug in the AWS Provider: https://github.com/terraform-providers/terraform-provider-aws/issues/10088

```
When expanding the plan for
module.cf_distrib.aws_cloudfront_distribution.distrib to include new values
learned so far during apply, provider "registry.terraform.io/-/aws" produced
an invalid new value for .origin: planned set element
cty.ObjectVal(map[string]cty.Value{"custom_header":cty.SetValEmpty(cty.Object(map[string]cty.Type{"name":cty.String,
"value":cty.String})),
"custom_origin_config":cty.ListValEmpty(cty.Object(map[string]cty.Type{"http_port":cty.Number,
"https_port":cty.Number, "origin_keepalive_timeout":cty.Number,
"origin_protocol_policy":cty.String, "origin_read_timeout":cty.Number,
"origin_ssl_protocols":cty.Set(cty.String)})),
"domain_name":cty.StringVal("cf-distrib-demo-default-bucket.s3.amazonaws.com"),
"origin_id":cty.StringVal("cf-distrib-demo-default-bucket"),
"origin_path":cty.NullVal(cty.String),
"s3_origin_config":cty.ListVal([]cty.Value{cty.ObjectVal(map[string]cty.Value{"origin_access_identity":cty.StringVal("origin-access-identity/cloudfront/EXAMPLE")})})})
does not correlate with any element in actual.
```

## Improvements
* Can easily turn on versioning for the default bucket. I haven't done it since it was a PITA to delete versions and test without a script and I am running short of time.
* Can turn on https ONLY on the distribution and increase TLS to TLS1.2 
* Implement KMS encrypted environment variable encryption for basic auth in Lambda@Edge instead of hardcoding it. 
 * Lambda@Edge is enabled only in `us-east-1` hence to keep it simple I have kept the infrastructure in `us-east-1`  region at the expense of latency

 
### Live Demo 

SPA: https://secure-cf-demo.ganeshheg.de

Static: https://secure-cf-demo.ganeshheg.de/static/cat.jpg