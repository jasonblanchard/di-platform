add_repo:
	helm repo add banzaicloud-stable https://kubernetes-charts.banzaicloud.com

generate_manifests: add_repo
	helm template vault-operator banzaicloud-stable/vault-operator --output-dir ./kustomize

clean:
	rm -rf ./kustomize/templates/
