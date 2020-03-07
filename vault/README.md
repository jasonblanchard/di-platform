# Setting up Vault

## Run Vault in the cluster
Grab Vault k8s manifests. Use Helm to write it to the file system to avoid using Tiller:

```
$ helm template --name vault --namespace playground ./ > ../kube-playground/vault/vault.yml
```

Then apply it like this:

```
$ kubectl apply -f vault.yml
```

This should spin up a Vault pod, service, etc. using the default settings and filesystem storage.

## Setting up Vault
Forward local ports to the Vault server:

```
kubectl port-forward service/vault 8200:8200
```

Set up env to use your Vault instance:

```
VAULT_ADDR=http://localhost:8200
VAULT_TOKEN=
VAULT_SKIP_VERIFY=true
```

Initialize the vault:

```
vault operator init
```

Unseal the vault using those keys like this https://www.vaultproject.io/intro/getting-started/deploy.html#seal-unseal

Log in to vault with the Initial Root Token:

```
vault login <TOKEN>
```

Initialize the KV secret engine:

```
vault secrets enable -path=kv kv
```

> TODO: Create an admin role and bind it to k8s SA that can do admin-ey things that's not the root user. Give it access to `secret/data/*`, `sys/policies/acl/*`, `auth/kubernetes/role/*`, `transit/keys/*`, `transit/encrypt/*`, `transit/decrypt/*`, `transit/rewrap/*`. Create a login script to log in as him

You should be able to write secrets now like this:

```
vault write kv/my-secret value="s3c(eT"
```
## Configuring Kubernetes auth
Create the `vault-auth` service account. This is the service account that is used to validate tokens from _other_ service accounts:

```
kubectl apply -f vault-auth-service-account.yml
```

Run the setup script:

```
./setup.sh https://192.168.64.5:8443
```

Where `https://192.168.64.5:8443` is the host of the k8s cluster. You can find this with `kubectl config view` and find the cluster you are connected to.

This will spit out a bunch of commands that you need to run to wire up Vault to the Kubernetes cluster via the `vault-auth` service account. Hold off on running the service account => role bundings until creating the service account and policy for a service.

## Creating service account for a service
Create a Service Account, Role and RoleBinding for the service like in `sa.yml`:

```
kubectl apply -f sa.yml
```

Create a Vault policy for your app like in `my-service-kv.hcl` and write it to Vault:

```
vault policy write dev-my-service my-service-kv.hcl
```

Now, use this service account and policy to bind the role in Vault (based off the output from setup.sh above):

```
vault write auth/kubernetes/role/my-service-rw-role bound_service_account_names=my-service bound_service_account_namespaces=di policies=dev-my-service ttl=24h
```

You should now be able to use that k8s service account to authenticate and read from that kv store. You can test this by running `login.sh` and trying to read from the path you gave them access to:

```
vault kv get kv/secret/data/dev/my-service/app
```

## Using the service account for a service
Add the service account name at `spec.template.spec.serviceAccountName`. This will mount the service account `token` and `ca` secrets at `/var/run/secrets/kubernetes.io/serviceaccount` inside the pod container.

## Injecting secrets into running pods with mutating webhook
Grab the [repo](https://github.com/banzaicloud/bank-vaults/tree/master/charts/vault-secrets-webhook) and write the helm template to the filesystem (to avoid using Tiller):

```
helm template ./ > ~/projects/kube-playground/vault/webhook.yml
```

Follow the instructions to create the namespace:
```
export WEBHOOK_NS=vswh
WEBHOOK_NS=${WEBHOOK_NS:-vswh}
kubectl create namespace "${WEBHOOK_NS}"
kubectl label ns "${WEBHOOK_NS}" name="${WEBHOOK_NS}"
```

This namespace stuff is important for some reason. It didn't work without it.

Install the stuff:

```
kubectl apply -f webhook.yml
```

Annotate your pods at `spec.template.metadata.annotations` like this:
```
vault.security.banzaicloud.io/vault-addr: http://vault.playground.svc.cluster.local:8200
vault.security.banzaicloud.io/vault-role: say-hello-rw-role
vault.security.banzaicloud.io/vault-skip-verify: "true"
vault.security.banzaicloud.io/vault-path: kubernetes
```

The host for `vault.security.banzaicloud.io/vault-addr` is `http://[service].[namespace].svc.cluster.local:8200`

The value for `vault.security.banzaicloud.io/vault-role` should be the service account role you want to authenticate to vault with.

Create a ConfigMap that uses the vault keyword in the value along with the secret path, like:

```
vault:kv/secret/data/dev/my-service/app#DB_PASSWORD
```

Run your service or job. When you inspect the pod with `kubectl get pods [POD] -o yaml`, you should see that the webhook added a `initContainers` config that drops the `vault-env` binary in your image and then changes your container's `command` to leverage `/vault/vault-env` by passing your command as an argument.

If your process makes use of the environment variable via the ConfigMap key, it'll be the use the decrypted value at the vault path from the key. If you inspect the container in a different process and `printenv` the value, you'll see the `vault:*` path, NOT the decrypted value. Which is pretty neat.

## Naming patterns per service

|k8s SA name|k8s Role name|k8s RoleBinding name|Vault Policy name|Vault Secrets Path|
|-|-|-|-|-|
|`[service-name]`|`[service-name]-rw-role`|`[service-name]-binding`|`[environment]-[service-name]`|`kv/secret/data/[environment]/[service-name]/app`

SAs should get `["create", "read", "list"]` access to their secrets

## Encrypting and storing secrets in the repo
TODO: Using sanctum
