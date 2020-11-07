#! /bin/bash
kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-server -o name | cut -d'/' -f 2

kubectl port-forward svc/argocd-server -n argocd 8080:443
