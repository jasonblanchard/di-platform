# Bootstrapping Cluster

## Run Terraform to create cluster
TODO

## Create `di` namespace
`kubectl apply -f namespace`

## Start nats
`kubectl apply -f nats -n di`

## Set up Vault
1. `kubectl apply -k vault-operator/kustomize`
2. `kubectl apply -k vault-secrets-webhook/kustomize`
3. `kubectl apply -k vault/kustomize`

Port forward to Vault:
`kubectl port-forward vault-0 8200:8200 -n vault`

Login to Vault as the secret administrator:
```
export VAULT_ADDR=https://127.0.0.1:8200
export VAULT_SKIP_VERIFY=true
export VAULT_TOKEN=$(vault login -method=github token=<token> | grep -E "^token\s+.+$" | awk '{print $2}')
```

Init transit secret:
`make init_transit_key`

## Start Ambassador gateway
`kubectl apply -f ambassador -n di`

## For each service
Follow [Bootstrapping a Service](bootstrap_service.md)
