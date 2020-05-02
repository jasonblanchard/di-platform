# Set up AWS
This terraform will create a microk8s cluster on a single EC2 node.

Apply terraform in this order (cd into each directory and run `terraform apply`):
1. kubeconfig
2. iam
3. vpc
4. cluster

The final `cluster` module will spin up an EC2 instance, and:
1. Install microk8s and enable dns and ingress
2. Ship a kubeconfig file to s3
3. Create a self-signed TLS cert
4. Create a k8s secret called `tls-secret` which can be referenced in an ingress k8s config
5. output the `cluster_public_dns`. Update `ingress.yaml` hosts to use this host.


Run `source ./scripts/kubeconfig.sh` to set up the kubernetes context. You should now be set up to apply kubernetes manifests on the remote cluster.
