# Objectives: (for this Makefile)
#	- minimize external dependencies
#	- prepare baseline certificate management for a nested Kubernetes cluster
#	- provide limited deployment management automation for nested Kubernetes
#
# Considerations:
# 	- OpenSSL will be used for certificate generation and cryptographic functions, as it's quite ubiquitous.



HOST_DEPLOYMENT_YAML := .tmp/host.deployment.yaml
GUEST_DEPLOYMENT_YAML := .tmp/guest.deployment.yaml
HOST_YAML := $(shell ls -1 ./manifest/host.*.yaml)
GUEST_YAML := $(shell ls -1 ./manifest/guest.*.yaml)
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

GUEST_CONFIG := ./kubeception.kubeconfig


export CLUSTER_NAME MASTER_IP MASTER_CLUSTER_IP

.PHONY: up down deploy test clean

all: up certs deploy $(GUEST_CONFIG)

up:
	minikube status | grep -i stopped || exit 0
	minikube start --cpus 4

down:
	minikube stop	


$(HOST_DEPLOYMENT_YAML): $(HOST_YAML)
	mkdir -p $(@D)  # make temp dir
	cat $^ > $@

$(GUEST_DEPLOYMENT_YAML): $(GUEST_YAML)
	mkdir -p $(@D)  # make temp dir
	cat $^ > $@


# Seconds to wait for guest API server to come up.
DELAY := 30 

# prerequisites
deploy: $(GUEST_CONFIG) host-secrets

deploy:  $(HOST_DEPLOYMENT_YAML) $(GUEST_DEPLOYMENT_YAML) 
	# Fail if not running in minikube
	kubectl config current-context | grep -q minikube || exit 1
	kubectl apply -f $(HOST_DEPLOYMENT_YAML)

	# Apply policy bits inside the guest cluster.
	# The host cluster might need a short window to create the containers.
	scripts/innerkube -d $(DELAY) -c $(GUEST_CONFIG) -n $(CLUSTER_NAME) --\
		apply -f $(GUEST_DEPLOYMENT_YAML)


deploy-guest-nginx: $(GUEST_CONFIG)
	KUBECONFIG=$(GUEST_CONFIG) kubectl run nginx --image=nginx:latest \
		--replicas=2 --port=80 --expose


test: deploy deploy-guest-nginx
	-echo "(testing the guest deployment)"


# Certificate preparation
# cf https://kubernetes.io/docs/concepts/cluster-administration/certificates/


$(CLUSTER_NAMES):
	echo 'localhost' > $@
	echo $(COMMON_NAME){,.default{,.svc{,.cluster{,.local}}}} \
		| tr -s ' ' '\n' >> $@
	

.PHONY: ca	
ca: certs/ca.key certs/ca.crt 

COMPONENT_KEYS := $(shell echo certs/user.{controller,scheduler,proxy,volume,kubelet}.{key,pub})
COMPONENT_CERTS := $(shell echo certs/user.{controller,scheduler,proxy,volume,kubelet}.crt)
COMPONENTS := $(shell echo certs/system.{scheduler,controller,proxy,volume,kubelet}.kubeconfig)

.PHONY: certs
certs: certs/apiserver_tokens.csv
certs: certs/ca.crt 
certs: certs/system.apiserver.crt certs/system.apiserver.key    # apiserver
certs: certs/system.etcdclient.crt certs/system.etcdclient.key  # for apiserver
certs: certs/system.etcdserver.crt certs/system.etcdserver.key  # etcd
certs: certs/user.admin.crt certs/user.admin.key                # initial user
certs: certs/user.kubelet.crt certs/user.kubelet.key            # kubelet
certs: $(COMPONENTS) $(COMPONENT_CERTS) $(COMPONENT_KEYS)

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

.PRECIOUS: certs/%.key
certs/%.key:
	openssl genrsa -out $@ 2048

.PRECIOUS: certs/%.pub
certs/%.pub: certs/%.key
	openssl rsa -in $< -pubout > $@

certs/user.%.groups: certs/groups.txt
	grep '^$*:' $< | cut -d ':' -f 2- | tr -d ' ' > $@


certs/system.%.csr: certs/system.%.key $(CERT_CONFIG)
	# @cat -n "$(CERT_CONFIG)"; echo; sync
	openssl req -new -key $< -out $@ -subj "/CN=$*"

.PRECIOUS: certs/%.key
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

# Prepare a kubeconfig for internal system components, e.g. scheduler
.PRECIOUS: certs/system.%.kubeconfig
certs/system.%.kubeconfig: template/kubeconfig certs/ca.crt certs/user.%.crt
	cp -v $< $@
	kubectl config set-cluster kubeception \
		--server="https://kubernetes-kubeception:443" \
		--certificate-authority=certs/ca.crt \
		--embed-certs=true \
		--kubeconfig=$@
	kubectl config set-credentials system_component \
		--client-certificate=certs/user.$*.crt \
		--client-key=certs/user.$*.key \
		--embed-certs=true \
		--kubeconfig=$@
	kubectl config set-context kubeception \
		--user=system_component \
		--cluster=kubeception \
		--kubeconfig=$@
	kubectl config use-context kubeception --kubeconfig=$@



# In the host cluster, generate secrets for the various components.
host-secrets: host-secrets-cleanup  certs
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
		--from-file=controller.pub=certs/user.controller.pub \
		--from-file=tokens.csv=certs/apiserver_tokens.csv
	# keys/etc needed for kubelet, an API server client
	kubectl create secret --namespace $(CLUSTER_NAME) generic kubelet.kubeception \
		--from-file=ca.crt=certs/ca.crt \
		--from-file=api.crt=certs/system.apiserver.crt \
		--from-file=kubelet.crt=certs/user.kubelet.crt \
		--from-file=kubelet.key=certs/user.kubelet.key \
		--from-file=kubelet.kubeconfig=certs/system.kubelet.kubeconfig
	# controller needs some special bits for signing tokens.
	kubectl create secret --namespace $(CLUSTER_NAME) generic controller.kubeception \
		--from-file=ca.crt=certs/ca.crt \
		--from-file=controller.key=certs/user.controller.key \
		--from-file=controller.pub=certs/user.controller.pub \
		--from-file=controller.crt=certs/user.controller.crt
	# kubeconfig bits for various components
	kubectl create secret --namespace $(CLUSTER_NAME) generic system.kubeconfig.kubeception \
		$(foreach k, $(COMPONENTS), --from-file=$(notdir $(k))=$(k))
	

host-secrets-cleanup:
	for i in etcdserver apiserver kubelet certauth controller system.kubeconfig; do \
		kubectl delete --namespace $(CLUSTER_NAME) secret "$$i.kubeception" || true; \
		done

# Remove the deployments of the interior cluster.
deployment-cleanup:
	kubectl config current-context | grep minikube && \
		kubectl get deployment -n kubeception --no-headers -o name \
	 	| cut -d '/' -f 2 \
		| xargs -n 1 kubectl delete deployment -n kubeception || exit 0


# A local port forward into the inner cluster's API server
kubeception-portforward:
	kubectl port-forward -n $(CLUSTER_NAME) svc/kubernetes 8443:443

# A local kubeconfig to reach the inner cluster
$(GUEST_CONFIG): template/kubeconfig $(AUTH_TOKEN) | certs Makefile
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