#! /bin/bash

# Assumes you are port-forwarding to vault on localhost:
# kubectl port-forward vault-0 8200:8200 -n vault

export VAULT_ADDR=https://127.0.0.1:8200
export VAULT_SKIP_VERIFY=true
export VAULT_TOKEN=$(vault login -method=github | grep -E "^token\s+.+$" | awk '{print $2}')
