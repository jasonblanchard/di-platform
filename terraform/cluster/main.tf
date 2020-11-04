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

data "terraform_remote_state" "kubeconfig" {
  backend = "s3"

  config = {
    bucket = "di-terraform"
    key    = "kubeconfig/terraform.tfstate"
    region = "us-east-1"
  }
}

data "terraform_remote_state" "vault_backend" {
  backend = "s3"

  config = {
    bucket = "di-terraform"
    key    = "vault-backend/terraform.tfstate"
    region = "us-east-1"
  }
}

// IAM

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

// TODO: Move to kubeconfig?
resource "aws_iam_policy" "kubeconfig_read_write" {
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

resource "aws_iam_policy" "route53_read_write" {
  name        = "DiRoute53ReadWrite"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
      {
          "Sid" : "AllowPublicHostedZonePermissions",
          "Effect": "Allow",
          "Action": [
              "route53:ChangeResourceRecordSets"
          ],
          "Resource": "*"
      }
    ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "kubeconfig_read_write_to_cluster_instance" {
  role       = aws_iam_role.cluster_instance.name
  policy_arn = aws_iam_policy.kubeconfig_read_write.arn
}

resource "aws_iam_role_policy_attachment" "vault_read_to_cluster_instance" {
  role       = aws_iam_role.cluster_instance.name
  policy_arn = data.terraform_remote_state.vault_backend.outputs.vault_read_policy_arn
}

resource "aws_iam_role_policy_attachment" "route53_read_write_to_cluster_instance" {
  role       = aws_iam_role.cluster_instance.name
  policy_arn = aws_iam_policy.route53_read_write.arn
}

// Instance

resource "aws_launch_configuration" "node" {
  name_prefix = "di-k8s-node-"
  image_id = "ami-068663a3c619dd892"
  instance_type = "t3a.medium"
  security_groups = [data.terraform_remote_state.vpc.outputs.security_group_web_id, data.terraform_remote_state.vpc.outputs.security_group_dmz_id]
  iam_instance_profile   = aws_iam_role.cluster_instance.id

  lifecycle {
    create_before_destroy = true
  }

  user_data              = <<EOT
#!/bin/bash
sudo apt-get update
sudo apt-get install awscli git-core -y

sudo snap install kustomize
sudo snap install microk8s --classic --channel=1.18/stable
sudo microk8s status --wait-ready
sudo microk8s enable dns ingress
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

# Create self-signed TLS certs to allow HTTPS connections
PUBLIC_HOSTNAME=$(curl http://169.254.169.254/latest/meta-data/public-hostname)
KEY_FILE=server.key
CERT_FILE=server.crt
openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout $KEY_FILE -out $CERT_FILE -subj "/CN=$PUBLIC_HOSTNAME/O=$PUBLIC_HOSTNAME"
microk8s kubectl create secret tls instance-tls-secret --key $KEY_FILE --cert $CERT_FILE

DOMAIN_NAME=di.blanktech.net
openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout $KEY_FILE -out $CERT_FILE -subj "/CN=$PUBLIC_HOSTNAME/O=$PUBLIC_HOSTNAME"
microk8s kubectl create secret tls di-blanktech-net-tls-secret --key $KEY_FILE --cert $CERT_FILE

cd ~

# Initial cluster setup
git clone https://github.com/jasonblanchard/di-platform
cd di-platform

microk8s kubectl apply -f namespace
microk8s kubectl apply -k kube-state-metrics
microk8s kubectl apply -k metrics

INGRESS="$(cat <<-SCRIPT
apiVersion: networking.k8s.io/v1beta1
kind: Ingress
metadata:
  name: ingress
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
  namespace: di
spec:
  tls:
    - hosts:
      - $PUBLIC_HOSTNAME
      secretName: instance-tls-secret
    - hosts:
      - $DOMAIN_NAME
      secretName: di-blanktech-net-tls-secret
  rules:
    - host: $PUBLIC_HOSTNAME
      http:
        paths:
        - path: /
          backend:
            serviceName: ambassador
            servicePort: 80
    - host: $DOMAIN_NAME
      http:
        paths:
        - path: /
          backend:
            serviceName: ambassador
            servicePort: 80
SCRIPT
)"

echo "$INGRESS" | microk8s kubectl apply -f -

microk8s kubectl apply -k vault-operator/kustomize
microk8s kubectl apply -k vault-secrets-webhook/kustomize

CHANGESET="$(cat <<-CHANGESET
{
  "Changes": [
    {
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "di.blanktech.net.",
        "Type": "CNAME",
        "TTL": 60,
        "ResourceRecords": [
          {
            "Value": "$PUBLIC_HOSTNAME"
          }
        ]
      }
    }
  ]
}
CHANGESET
)"

echo $CHANGESET > changeset.json

aws route53 change-resource-record-sets --hosted-zone-id Z1LII87WIHHZ1Y --change-batch file://$(pwd)/changeset.json

# Wait for vault stuff to initialize
sleep 60

microk8s kubectl apply -k nats

aws s3 cp s3://di-vault-backend/aws-cred.yaml ./vault/kustomize
microk8s kubectl apply -k vault/kustomize

microk8s kubectl apply -k ambassador

# Wait for ambassador to wake up
sleep 20

microk8s kubectl apply -k argocd

git clone https://github.com/jasonblanchard/di-deploy
cd di-deploy

kustomize build applications/ | microk8s kubectl apply -f -

# Re-run user-data script on start
echo "@reboot curl http://169.254.169.254/latest/user-data | sudo bash -" | crontab -
EOT

  root_block_device {
    volume_size = 32
  }
}

resource "aws_autoscaling_group" "cluster" {
  name = "di-cluster"
  launch_configuration = aws_launch_configuration.node.name
  min_size = 0
  max_size = 1
  desired_capacity = 0
  vpc_zone_identifier = [data.terraform_remote_state.vpc.outputs.public_subnet_id]

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_schedule" "cluster_up" {
  scheduled_action_name = "DiClusterUp"
  max_size = 1
  desired_capacity = 1
  recurrence = "0 12 * * *"
  autoscaling_group_name = aws_autoscaling_group.cluster.name
}

resource "aws_autoscaling_schedule" "cluster_down" {
  scheduled_action_name = "DiClusterDown"
  max_size = 1
  desired_capacity = 0
  recurrence = "0 4 * * *"
  autoscaling_group_name = aws_autoscaling_group.cluster.name
}
