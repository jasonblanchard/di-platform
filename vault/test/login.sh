# !/usr/bin/env bash

export VAULT_ADDR=https://127.0.0.1:8200
export VAULT_SKIP_VERIFY=true
SA_SECRET=$(kubectl get secret -n platform-test |grep platform-test|awk '{print $1}')
SA_TOKEN=$(kubectl get secret $SA_SECRET -n platform-test -o jsonpath="{.data.token}" | base64 --decode; echo)
VAULT_LOGIN_TOKEN=$(vault write auth/kubernetes/login role=platform-test jwt=$SA_TOKEN|grep -E "^token\s+.+$"|awk '{print $2}')
export VAULT_TOKEN=$(vault login -token-only token=$VAULT_LOGIN_TOKEN)
