provider "aws" {
  region = "us-east-1"
}

terraform {
  backend "s3" {
    bucket = "di-terraform"
    key    = "iam/terraform.tfstate"
    region = "us-east-1"
  }
}

data "terraform_remote_state" "kubeconfig" {
  backend = "s3"

  config = {
    bucket = "di-terraform"
    key    = "kubeconfig/terraform.tfstate"
    region = "us-east-1"
  }
}

resource "aws_iam_role" "cluster_instance" {
  name = "DiClusterInstance"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF

  tags = {
    Name = "DiClusterInstance"
  }
}

resource "aws_iam_instance_profile" "cluster_instance" {
  name = "DiClusterInstance"
  role = aws_iam_role.cluster_instance.name
}

resource "aws_iam_policy" "s3_read_write" {
  name        = "DiKubeconfigS3ReadWRite"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
              "s3:PutObject",
              "s3:GetObject"
            ],
            "Resource": ["arn:aws:s3:::${data.terraform_remote_state.kubeconfig.outputs.kubeconfig_bucket_id}/*"]
        }
    ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "s3_read_write_to_cluster_instance" {
  role       = aws_iam_role.cluster_instance.name
  policy_arn = aws_iam_policy.s3_read_write.arn
}

output "cluster_instance_role_id" {
  value = aws_iam_instance_profile.cluster_instance.id
}

output "cluster_instance_profile_id" {
  value = aws_iam_role.cluster_instance.id
}
