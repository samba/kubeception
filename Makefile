# Objectives: (for this Makefile)
#	- minimize external dependencies
#	- prepare baseline certificate management for a nested Kubernetes cluster
#	- provide limited deployment management automation for nested Kubernetes
#
# Considerations:
# 	- OpenSSL will be used for certificate generation and cryptographic functions, as it's quite ubiquitous.



DEPLOYMENT_YAML := .tmp/deployment.yaml
SOURCE_YAML := $(shell ls -1 ./manifest/*.yaml)
CSR_TEMPLATE := template/openssl.conf
CERTIFICATE_VALID_DAYS := 30000


# Administrative identity
COUNTRY := US
STATE := Washington
CITY := Seattle
ORGANIZATION := example.com
ORGUNIT := platform
COMMON_NAME := kubernetes


# Infrastructure seed identity
MASTER_IP ?= 10.0.0.1          # apiserver host
MASTER_CLUSTER_IP ?= 10.0.0.1  # apiserver load balancer

CLUSTER_NAME := kubeception
USERNAME ?= admin
USERID := $(shell echo $(CLUSTER_NAME) $(USERNAME) "$(shell date)" | openssl md5 -hex)
CERT_CONFIG := certs/cluster.$(CLUSTER_NAME).config
AUTH_TOKEN := certs/cluster.$(CLUSTER_NAME).token
CLUSTER_NAMES := certs/cluster.$(CLUSTER_NAME).names



export CLUSTER_NAME MASTER_IP MASTER_CLUSTER_IP

.PHONY: up down deploy test clean

all: up certs deploy kubeception.kubeconfig

up:
	minikube status | grep -i stopped || exit 0
	minikube start --cpus 4

down:
	minikube stop	


$(DEPLOYMENT_YAML): $(SOURCE_YAML)
	mkdir -p $(@D)  # make temp dir
	cat $^ > $@

.tmp/deployment.ts:  $(DEPLOYMENT_YAML) kubeception.kubeconfig | host-secrets
	# Fail if not running in minikube
	kubectl config current-context | grep -q minikube || exit 1
	kubectl apply -f $<
	touch -r $< $@

deploy:  .tmp/deployment.ts 

test: deploy
	echo "TODO: test the deployment."


# Certificate preparation
# cf https://kubernetes.io/docs/concepts/cluster-administration/certificates/


$(CLUSTER_NAMES):
	echo 'localhost' > $@
	echo $(COMMON_NAME){,.default{,.svc{,.cluster{,.local}}}} \
		| tr -s ' ' '\n' >> $@
	

.PHONY: ca	
ca: certs/ca.key certs/ca.crt 

.PHONY: certs
certs: certs/apiserver_tokens.csv
certs: certs/ca.crt 
certs: certs/system.apiserver.crt certs/system.apiserver.key    # apiserver
certs: certs/system.etcdclient.crt certs/system.etcdclient.key  # for apiserver
certs: certs/system.etcdserver.crt certs/system.etcdserver.key  # etcd
certs: certs/user.admin.crt certs/user.admin.key                # initial user
certs: certs/user.kubelet.crt certs/user.kubelet.key            # kubelet


# The CA is a self-signed certificate
certs/ca.crt: certs/ca.key
	openssl req -x509 -new -nodes -key $< -out $@ \
		-days $(CERTIFICATE_VALID_DAYS) \
		-subj "/CN=kubernetes-ca"


# Generate token files (name dynamic)
certs/%.token: 
	dd if=/dev/urandom bs=128 count=1 2>/dev/null \
		| base64 \
		| tr -d "=+/[:space:]" \
		| dd bs=32 count=1 >$@ 2>/dev/null

certs/apiserver_tokens.csv: $(AUTH_TOKEN)
	echo "$(shell cat $(AUTH_TOKEN)),admin,$(USERID),\"system:masters\"" > $@

certs/%.config: $(CSR_TEMPLATE) | Makefile
	sed -e 's@<MASTER_IP>@$(MASTER_IP)@; s@<MASTER_CLUSTER_IP>@$(MASTER_CLUSTER_IP)@;' > $@ < $<


certs/%.key:
	openssl genrsa -out $@ 2048

certs/user.%.groups: certs/groups.txt
	grep '^$*:' $< | cut -d ':' -f 2- | tr -d ' ' > $@


certs/system.%.csr: certs/system.%.key $(CERT_CONFIG)
	# @cat -n "$(CERT_CONFIG)"; echo; sync
	openssl req -new -key $< -out $@ -subj "/CN=$*"

certs/%.crt: certs/%.csr certs/ca.key certs/ca.crt $(CERT_CONFIG)
	openssl x509 -req -in $< -CA certs/ca.crt -CAkey certs/ca.key \
		-CAcreateserial -out $@ -days $(CERTIFICATE_VALID_DAYS) \
		-extfile "$(CERT_CONFIG)" -extensions "$*"


# User certificates must register the Kubernetes API groups that they're members of.
# Overrides the CSR rule above for users only.
certs/user.%.csr: certs/user.%.key certs/user.%.groups
	openssl req -new -key $< -out $@ -subj "/CN=$*/O=$(shell cat certs/user.$*.groups)"



cert-cleanup:
	rm -rvf certs/*.key certs/*.crt certs/*.csr
	rm -rvf $(CERT_CONFIG)
	rm -rvf certs/*.csv
	rm -rvf certs/*.token
	rm -rvf certs/*.groups


# In the host cluster, generate secrets for the various components.
host-secrets: host-secrets-cleanup | certs
	kubectl create namespace $(CLUSTER_NAME) || true
	kubectl create secret --namespace $(CLUSTER_NAME) generic certauth.kubeception \
		--from-file=ca.crt=certs/ca.crt
	# keys/etc needed for the etcd server
	kubectl create secret --namespace $(CLUSTER_NAME) generic etcdserver.kubeception \
		--from-file=ca.crt=certs/ca.crt \
		--from-file=server.key=certs/system.etcdserver.key \
		--from-file=server.crt=certs/system.etcdserver.crt
	# keys/etc needed for the API server (an etcd client)
	kubectl create secret --namespace $(CLUSTER_NAME) generic apiserver.kubeception \
		--from-file=ca.crt=certs/ca.crt \
		--from-file=etcd.crt=certs/system.etcdclient.crt \
		--from-file=etcd.key=certs/system.etcdclient.key \
		--from-file=api.crt=certs/system.apiserver.crt \
		--from-file=api.key=certs/system.apiserver.key \
		--from-file=tokens.csv=certs/apiserver_tokens.csv
	# keys/etc needed for kubelet, an API server client
	kubectl create secret --namespace $(CLUSTER_NAME) generic kubelet.kubeception \
		--from-file=ca.crt=certs/ca.crt \
		--from-file=api.crt=certs/system.apiserver.crt \
		--from-file=kubelet.crt=certs/user.kubelet.crt \
		--from-file=kubelet.key=certs/user.kubelet.key
	

host-secrets-cleanup:
	for i in etcdserver.kubeception apiserver.kubeception kubelet.kubeception certauth.kubeception; do \
		kubectl delete --namespace $(CLUSTER_NAME) secret $$i || true; \
		done

# Remove the deployments of the interior cluster.
deployment-cleanup:
	kubectl config current-context | grep minikube && \
		kubectl get deployment -n kubeception --no-headers -o name \
	 	| cut -d '/' -f 2 \
		| xargs -n 1 kubectl delete deployment -n kubeception || exit 0

# A local port forward into the inner cluster's API server
kubeception-portforward:
	kubectl port-forward -n kubeception svc/kubeception-apiserver 8443:443

# A local kubeconfig to reach the inner cluster
kubeception.kubeconfig: template/kubeconfig $(AUTH_TOKEN) | certs Makefile
	cp -v $< $@
	kubectl config set-cluster kubeception \
		--server="https://localhost:8443" \
		--certificate-authority=certs/ca.crt \
		--embed-certs=true \
		--kubeconfig=$@
	kubectl config set-credentials kubeception_admin \
		--client-certificate=certs/user.admin.crt \
		--client-key=certs/user.admin.key \
		--token="$(shell cat $(AUTH_TOKEN))" \
		--embed-certs=true \
		--kubeconfig=$@
	kubectl config set-context kubeception \
		--user=kubeception_admin \
		--cluster=kubeception \
		--kubeconfig=$@
	kubectl config use-context kubeception --kubeconfig=$@
	@echo "> TO USE INNER CLUSTER: export KUBECONFIG=$(PWD)/$@"

clean: cert-cleanup deployment-cleanup