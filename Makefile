start_local_cluster:
	minikube start --kubernetes-version=1.17.3

clean_local_cluster:
	minikube stop
	minikube delete
