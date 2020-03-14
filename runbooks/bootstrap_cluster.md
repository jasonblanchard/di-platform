# Bootstrapping Cluster

## Run Terraform to create cluster
TODO

## Create `di` namespace
`kubectl apply -f namespace`

## Start nats
`kubectl apply -f nats`

## Set up Vault
1. `kubectl apply -k `vault-operator/kustomize`
2. `kubectl apply -k vault-secrets-webook/kustomize`
3. `kubectl apply -k vault/kustomize`

Login to Vault as the secret administrator:
`vault login -method=github token=<token>`

Init transit secret:
`make init_transit_key`

## Start Ambassador gateway
`kubectl apply -f ambassador -n di`

## For each service
1. Create secrets: `sanctum create secrets <environment> app`
2. Apply k8s manifests: `kubectl apply -k overlays/<environment>`
