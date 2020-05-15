# Bootstrapping Cluster

## Run Terraform to create cluster
Apply terraform in this order (cd into each directory and run `terraform apply`):
1. vpc
1. kubeconfig
1. vault-backend
1. cluster

The final `cluster` module will spin up an EC2 instance, and:
1. Install microk8s and enable dns and ingress
2. Ship a kubeconfig file to s3
3. Create a self-signed TLS cert
4. Create a k8s secret called `tls-secret` which can be referenced in an ingress k8s config
5. output the `cluster_public_dns`. Update `ingress.yaml` hosts to use this host.

Run `source ./scripts/kubeconfig.sh` to set up the kubernetes context. You should now be set up to apply kubernetes manifests on the remote cluster.

## Start nats
`kubectl apply -f nats -n di`

## Set up Vault
1. `kubectl apply -k vault-operator/kustomize`
2. `kubectl apply -k vault-secrets-webhook/kustomize`
3. See [vault README](../vault/README.md) for the last step, this is kind of annoying right now

Port forward to Vault:
`kubectl port-forward vault-0 8200:8200 -n vault`

Login to Vault as the secret administrator:
```
./scripts/vault
```

Init transit secret:
`make init_transit_key`

## Start Ambassador gateway
`kubectl apply -f ambassador -n di`

## For each service
Follow [Bootstrapping a Service](bootstrap_service.md)
