# Notes



## Shortcuts

Drop into a busybox shell
`kubectl delete pods --namespace kubeception busybox && kubectl run --namespace kubeception -i -t busybox --image=busybox --restart=Never -- /bin/sh`

Ensure that etcd is up...
`wget -q -O - https://kubeception-etcd:2379/health | grep health`

Or using curl...

```shell
curl -v --cacert /opt/kubernetes/certs/ca/tls.crt \
    --cert /opt/etcd/certs/client/tls.crt \
    --key /opt/etcd/certs/client/tls.key \
    https://kubeception-etcd:2379/health
```

Hyperkube args/opts help
`docker run -it --rm  gcr.io/google_containers/hyperkube:v1.10.4 /hyperkube kube-apiserver -h`


## Reference Material

https://kubernetes.io/docs/setup/scratch/
https://kubernetes.io/docs/setup/scratch/#bootstrapping-the-cluster
https://kubernetes.io/docs/setup/scratch/#apiserver-controller-manager-and-scheduler

https://kubernetes.io/docs/reference/access-authn-authz/authentication/#static-token-file
https://kubernetes.io/docs/reference/access-authn-authz/rbac/
https://kubernetes.io/docs/concepts/cluster-administration/certificates/#openssl

