provider "aws" {
  region = "us-east-1"
}

terraform {
  backend "s3" {
    bucket = "di-terraform"
    key    = "vault-backend/terraform.tfstate"
    region = "us-east-1"
  }
}

resource "aws_s3_bucket" "vault" {
  bucket = "di-vault-backend"
  acl    = "private"
}

// NOTE: For now, still need to make access key and secret in the console. Will need this later for vault.
resource "aws_iam_user" "vault" {
  name = "di-vault-service-account"
}

resource "aws_iam_policy" "s3_read_write" {
  name        = "DiVaultS3ReadWrite"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": "s3:*",
            "Resource": ["arn:aws:s3:::${aws_s3_bucket.vault.id}"]
        },
        {
            "Effect": "Allow",
            "Action": [
              "s3:PutObject",
              "s3:GetObject"
            ],
            "Resource": ["arn:aws:s3:::${aws_s3_bucket.vault.id}/*"]
        }
    ]
}
EOF
}

resource "aws_iam_policy" "vault_read" {
  name        = "DiVaultS3Read"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
              "s3:GetObject"
            ],
            "Resource": ["arn:aws:s3:::${aws_s3_bucket.vault.id}/*"]
        }
    ]
}
EOF
}

resource "aws_iam_user_policy_attachment" "vault_to_s3_read_write" {
  user = aws_iam_user.vault.name
  policy_arn = aws_iam_policy.s3_read_write.arn
}

resource "aws_kms_key" "vault_backend" {
  description             = "DI vault-backend"
}

resource "aws_kms_alias" "vault_backend" {
  name          = "alias/di-vault-backend"
  target_key_id = aws_kms_key.vault_backend.key_id
}

resource "aws_kms_grant" "vault_backend_key_to_vault_backend_user" {
  name              = "di-vault-backend"
  key_id            = aws_kms_key.vault_backend.key_id
  grantee_principal = aws_iam_user.vault.arn
  operations        = ["Encrypt", "Decrypt", "GenerateDataKey"]
}

output "vault_backend_id" {
  value = aws_s3_bucket.vault.id
}

output "kms_key_id" {
  value = aws_kms_key.vault_backend.id
}

output "vault_read_policy_arn" {
  value = aws_iam_policy.vault_read.arn
}
