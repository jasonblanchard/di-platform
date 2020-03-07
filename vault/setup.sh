#!/usr/bin/env bash

K8S_HOST=$1

if [ "$K8S_HOST" = "" ]; then
  echo "Must Specify k8s host name"
  exit 1
fi

kubectl apply -f vault-auth-service-account.yml

# Set VAULT_SA_NAME to the service account you created earlier
export VAULT_SA_NAME=$(kubectl get sa vault-auth -o jsonpath="{.secrets[*]['name']}")

# Set SA_JWT_TOKEN value to the service account JWT used to access the TokenReview API
export SA_JWT_TOKEN=$(kubectl get secret $VAULT_SA_NAME -o jsonpath="{.data.token}" | base64 --decode; echo)

# Set SA_CA_CRT to the PEM encoded CA cert used to talk to Kubernetes API
export SA_CA_CRT=$(kubectl get secret $VAULT_SA_NAME -o jsonpath="{.data['ca\.crt']}" | base64 --decode; echo)

echo "Run the following:"
echo "vault auth enable kubernetes"
echo "vault write auth/kubernetes/config token_reviewer_jwt=$SA_JWT_TOKEN kubernetes_host=$K8S_HOST kubernetes_ca_cert='$SA_CA_CRT'"
echo "vault write auth/kubernetes/role/<app role> bound_service_account_names=vault-auth bound_service_account_namespaces=default policies=<myapp policy> ttl=24h"
echo "The above SA does not have to be the same as the Token Reviewer SA - it will not be in a scenario where the token reviewer SA is setup in a specific namespace and the application is running in another (preferred)."
