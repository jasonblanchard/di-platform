provider "aws" {
  region = "us-east-1"
}

terraform {
  backend "s3" {
    bucket = "di-terraform"
    key    = "cluster/terraform.tfstate"
    region = "us-east-1"
  }
}

data "terraform_remote_state" "vpc" {
  backend = "s3"

  config = {
    bucket = "di-terraform"
    key    = "vpc/terraform.tfstate"
    region = "us-east-1"
  }
}

data "terraform_remote_state" "iam" {
  backend = "s3"

  config = {
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

resource "aws_instance" "master" {
  ami                    = "ami-068663a3c619dd892"
  instance_type          = "t2.medium"
  vpc_security_group_ids = [data.terraform_remote_state.vpc.outputs.security_group_web_id, data.terraform_remote_state.vpc.outputs.security_group_dmz_id]
  iam_instance_profile   = data.terraform_remote_state.iam.outputs.cluster_instance_profile_id
  subnet_id              = data.terraform_remote_state.vpc.outputs.public_subnet_id
  user_data              = <<EOT
#!/bin/bash
sudo apt-get update
sudo apt-get install awscli -y

sudo snap install microk8s --classic --channel=1.18/stable
sudo microk8s status --wait-ready
sudo microk8s enable dns dashboard ingress
sudo usermod -a -G microk8s ubuntu
sudo chown -f -R ubuntu ~/.kube

PUBLIC_IP=$(curl http://169.254.169.254/latest/meta-data/public-ipv4)

# Set up kubeconfig with public ip and ship it to S3 for later
sudo microk8s config > kubeconfig
ESCAPED_PUBLIC_ADDRESS="https:\/\/$PUBLIC_IP:16443"
sed -i "s/server.*/server: $ESCAPED_PUBLIC_ADDRESS/g" kubeconfig
aws s3 cp kubeconfig s3://${data.terraform_remote_state.kubeconfig.outputs.kubeconfig_bucket_id}

# Configure csr to allow remote kubectl access to public ip
sed -i "s/#MOREIPS/IP.5 = $PUBLIC_IP\\n#MOREIPS/" /var/snap/microk8s/current/certs/csr.conf.template
microk8s stop
microk8s start

# Create self-signed TLS cert to allow HTTPS connections
PUBLIC_HOSTNAME=$(curl http://169.254.169.254/latest/meta-data/public-hostname)
KEY_FILE=server.key
CERT_FILE=server.crt
openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout $KEY_FILE -out $CERT_FILE -subj "/CN=$PUBLIC_HOSTNAME/O=$PUBLIC_HOSTNAME"
kubectl create secret tls tls-secret --key $KEY_FILE --cert $CERT_FILE
EOT

  tags = {
    Name = "Di"
  }
}

output "cluster_public_dns" {
  value = aws_instance.master.public_dns
}

output "cluster_public_ip" {
  value = aws_instance.master.public_ip
}