variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-west-2"
}

variable "s3_bucket_name" {
  description = "Name of the S3 bucket for EA trading files"
  type        = string
  default     = "ea-trading-bucket"
}
