provider "aws" {
  region = "us-east-1"
}

terraform {
  backend "s3" {
    bucket = "di-terraform"
    key    = "kubeconfig/terraform.tfstate"
    region = "us-east-1"
  }
}

resource "aws_s3_bucket" "kubeconfig" {
  bucket = "di-kubeconfig"
  acl    = "private"
}

output "kubeconfig_bucket_id" {
  value = aws_s3_bucket.kubeconfig.id
}
