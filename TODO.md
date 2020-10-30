# Cluster-wide updates
1. Create production namespace
- TODO: Where should ambassador and nats live?

2. Update ambassador

# Refactor deploy flow
1. Clean up base manifests with better base kustomize
- Add commonLabels, nameSuffix, etc
- Standardize name prefixes (i.e. remove di-*)

2. Add argo applications in deploy project
- One per environment that patches the repo path and destination
- Include a kustomization to apply them all

3. Refactor services
- kustomization with a remote base pointing to the project repo
- overrides image tag
- add version to commonAnnotations
- add a Krmfile to configure the overrides

4. CI
- Add workflow_dispatch to deploy repo to kustomize cfg the service + environment tag
- Add deploy action that sends webhook to deploy repo dispatch

5. Update user_data script
- start argo
- apply all the applications to bootstrap them

# Use di-notebook instead of di-entry
- Run concurrently & benchmark
- Run data migration
- Downsize cluster?

# Refactor messages
- entry => notebook
- rename to semantic verbs, not CRUD actions

# UI/UX
- Make it better
- Keyboard shortcuts

# Experiments
- gRPC ingress
- more insights/gamification
