# Kubernetes in Kubernetes

This is a concept-proving codebase, a very early prototype. 
Code quality and architectural concerns will be improved with time.

**Be warned**, this codebase currently incorporates lots of hacks, and several known but unresolved issues.

# Motivation

Private cloud environments benefit greatly from the performance gains of bare-metal 
Kubernetes, but simultaneously require isolated administrative domains for individual customers (i.e. internal teams).

Operations teams need the flexibility of establishing a single, uniform platform for governing all computing resources. Application teams need the ability
to tune, upgrade, and administer their own Kubernetes clusters independent of the 
underlying infrastructure management.

## Goals 

- Prove the viability of a "guest cluster" model, where Kubernetes operates within Kubernetes.
- Rely predominantly on Kubernetes primitives and its functionality, and avoid extensive reliance on intermediate virtualization layers.

## Limitations 

Some concerns are not addressed (yet) in this model:
- Failure domains relevant to private infrastructure environments.
- Stringent isolation of virtual networks for guest clusters.

*(probably lots of others... feel free to file issues.)*

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

Moved to [GitHub issues][issues], actually. :)  
Related [Project Board][project].


[project]: https://github.com/samba/kubeception/projects/2
[issues]: https://github.com/samba/kubeception/issues