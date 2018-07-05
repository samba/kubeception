# Kubernetes in Kubernetes

This is a concept-proving codebase. Code quality and architectural concerns will be improved with time.

**Be warned**, this codebase currently incorporates lots of hacks.

# Usage

## Set up a local dev cluster

The following steps are intentionally separated to support phase testing.
Some components will produce 

```shell
make up             # brings up minikube
make certs          # generates keypairs for secrets
make deploy         # creates inner cluster w/ secrets in host cluster
make kubeception.kubeconfig
export KUBECONFIG=$(PWD)/kubeception.kubeconfig
kubectl cluster-info # show status of inner cluster
```

## Teardown

```shell
make deployment-cleanup # destroys deployments in cluster, keeps minikube cluster up
make down # destroys minikube cluster
```

## Known Issues

Nothing is highly available. Nothing is secure.

- [ ] Certificates: CA _key_ should **not** be stored in k8s.