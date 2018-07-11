# Kubernetes in Kubernetes

This is a concept-proving codebase, a very early prototype. 
Code quality and architectural concerns will be improved with time.

**Be warned**, this codebase currently incorporates lots of hacks, and several known but unresolved issues.



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

- [x] ~Certificates: CA _key_ should **not** be stored in k8s.~
- [x] ~kubelet pods don't register as nodes~
- [x] ~Deployments can't schedule pods...~ resolved w/ controller manager fix.
- [x] ~Possible `ClusterRoleBinding` issues preventing sufficient privileges for controller-manager (etc)~  resolved with controller manager's service account token management. 
- [x] ~Docker w/ kubelet fails to start containers.~
- [ ] Something in initial spinup of the guest cluster is slow. API server proxy fails, but retry succeeds.
- [ ] Services within the guest cluster don't resolve deployment names to pods to nodes, correctly... yet. (WIP w/ coredns)

