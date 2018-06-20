#!/usr/bin/env bash

set -x
set -euf -o pipefail

# Fail if not running in minikube
kubectl config current-context | grep minikube || exit 1


certs () {
  # these names are derived from the makefile products
  echo "ca" "ca.kubeception" 
  echo "server" "apiserver.kubeception"
  echo "etcd-server" "server.etcd.kubeception" 
  echo "etcd-client" "client.etcd.kubeception" 
}

kubectl create namespace kubeception || true

# Create secrets first.
while read fbase secretname; do
  kubectl delete --namespace "kubeception" secret $secretname || true
  kubectl create --namespace "kubeception" secret tls $secretname --cert=certs/${fbase}.crt --key=certs/${fbase}.key 
done < <(certs)


# Install all manifest components (command line arguments).
for f_yaml; do
  kubectl apply -f ${f_yaml} || exit $?
done

