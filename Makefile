.PHONY: pulumi

start_local_cluster:
	minikube start --kubernetes-version=1.17.3

clean_local_cluster:
	minikube stop
	minikube delete

init_transit_key:
	vault write -f transit/keys/sanctum

pulumi:
	go build -o ./bin/pulumi ./pulumi

provision: pulumi
	pulumi up