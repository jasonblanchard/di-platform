## Initializing Vault with S3 storage
1. Key and secret for di-vault-service-account
1. create credentials file based credentials.example with real values
1. Create base64 string: `cat ./vault/kustomize/credentials | base64 -`
1. Use that base64 string for the `credentials` data key in vault/kustomize/aws-cred.yaml based on aws-cred.yaml.example
1. apply that config
1. push config to encrypted bucket: `aws s3 cp ./vault/kustomize/aws-cred.yaml s3://di-vault-backend`
1. run vault `kubectl apply -k ./vault/kustomize`
1. `rm ./vault/kustomize/aws-cred.yaml`

## Re-initializing Vault on a new cluster node
1. Pull down config from bucket `aws s3 cp s3://di-vault-backend/aws-cred.yaml ./vault/kustomize`
1. `kubectl apply -k vault/kustomize`
1. `rm ./vault/kustomize/aws-cred.yaml`

Secrets should still be available from before
