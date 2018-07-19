# Notes

## Observations

- The hyperkube container provides `openssl`, so certificate generation can be executed within the host cluster in a familiar container.


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


Digging up logs from within the Kubelet container...

```shell
# jump into the kubelet container
kubectl exec -it  -n kubeception kubeception-kubelet-cc6f8c9f-skgz9 -- /bin/sh

# discover logs per guest container
find /var/log/pods  -type l -name '*.log'

# resolve the API server hostname within the cluster from kubelet container
getent hosts kubeception-apiserver
```

## Reference Material



### Certificate managment
https://github.com/coreos/coreos-kubernetes/blob/master/Documentation/openssl.md
https://github.com/mesosphere/kubernetes-keygen
https://github.com/mesosphere/kubernetes-keygen/blob/master/kube-certgen.sh
https://github.com/Microsoft/SDN/blob/master/Kubernetes/linux/certs/generate-certs.sh
https://jenciso.github.io/personal/manage-tls-certificates-for-kubernetes-users
https://kubernetes.io/docs/concepts/cluster-administration/certificates/#openssl
https://kubernetes.io/docs/reference/access-authn-authz/authentication/#static-token-file
https://kubernetes.io/docs/reference/access-authn-authz/rbac/
https://kubernetes.io/docs/setup/scratch/
https://kubernetes.io/docs/setup/scratch/#apiserver-controller-manager-and-scheduler
https://kubernetes.io/docs/setup/scratch/#bootstrapping-the-cluster
https://kubernetes.io/docs/tasks/tls/managing-tls-in-a-cluster/
https://security.stackexchange.com/questions/74345/provide-subjectaltname-to-openssl-directly-on-command-line
https://serverfault.com/questions/899353/how-to-inherit-the-commonname-to-the-subject-alternative-name
https://www.endpoint.com/blog/2013/10/29/ssl-certificate-sans-and-multi-level
https://www.endpoint.com/blog/2014/10/30/openssl-csr-with-alternative-names-one
https://www.openssl.org/docs/manmaster/man5/config.html


### Cluster setup
https://www.ibm.com/support/knowledgecenter/en/SSMNED_5.0.0/com.ibm.apic.install.doc/tapic_install_Kubernetes.html



### Role bindings and permissions for core components

Example
https://github.com/kubernetes/kubernetes/blob/v1.8.0/plugin/pkg/auth/authorizer/rbac/bootstrappolicy/testdata/cluster-role-bindings.yaml


### Cluster bootstrapping

https://mritd.me/2018/04/19/set-up-kubernetes-1.10.1-cluster-by-hyperkube/ (chinese)