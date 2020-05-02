# Bootstrapping a Service
Assuming a dockerize image available at `jasonblanchard/<service-name>:<sha>`

## Create base manifests
These live at `deploy/base`.

Kustomization resources should include:
- `sa.yaml` - ServiceAccount named after service
- `deployment.yaml`
- `service.yaml` (if needed)

## Set up Vault
In `di-platform/vault/kustomize/vauly.yaml, add:

- Policy named after service with RW access to `secret/data/<service>/*`
- Kubernetes role binding to ServiceAccount and Vault role

## Set up service secrets
1. Create `deploy/sanctum.yaml` (TODO: Move to root?). `prefix` should be set to vault secrets path.
2. Set up secrets `sanctum create -t <environment> secrets/<environment>/app`
3. Push secrets to vault `sanctum push -t <environment>`

## Set up environment overlays
In `deploy/overlays/<environment>`

## Run the services
`kubectl apply -k deploy/overlays/<environment>`
