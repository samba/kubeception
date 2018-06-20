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