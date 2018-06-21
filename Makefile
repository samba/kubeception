
DEPLOYMENT_YAML := .tmp/deployment.yaml
SOURCE_YAML := $(shell ls -1 ./manifest/*.yaml)
CERTIFICATE_VALID_DAYS := 30000

MASTER_IP := 10.0.0.1
MASTER_CLUSTER_IP := 10.0.0.1
ETCD_SERVICE = kubeception-etcd

CLUSTER_NAME := kubeception
USERNAME := admin
USERID := $(shell echo $(CLUSTER_NAME) "$(shell date)" | openssl md5 -hex)
CERT_CONFIG := certs/cluster.$(CLUSTER_NAME).conf
AUTH_TOKEN := certs/cluster.$(CLUSTER_NAME).token

export CLUSTER_NAME MASTER_IP MASTER_CLUSTER_IP

.PHONY: up down deploy test clean

up:
	minikube status | grep -i stopped || exit 0
	minikube start --cpus 4

down:
	minikube stop	


$(DEPLOYMENT_YAML): $(SOURCE_YAML)
	mkdir -p $(@D)
	cat $< > $@

.tmp/deployment.ts:  $(DEPLOYMENT_YAML)
	bash scripts/deploy-local.sh $<
	touch $@

deploy:  .tmp/deployment.ts 

test: deploy
	echo "TODO: test the deployment."


# TODO: generate a series of tokens for initial API auth


# Certificate preparation
# cf https://kubernetes.io/docs/concepts/cluster-administration/certificates/

$(CERT_CONFIG): certs/csr.conf scripts/setup_certs.sh
	# mkdir -p "$(dir $(CERT_CONFIG))/$(CLUSTER_NAME)"
	bash scripts/setup_certs.sh $< > $@

$(AUTH_TOKEN): 
	dd if=/dev/urandom bs=128 count=1 2>/dev/null \
		| base64 \
		| tr -d "=+/[:space:]" \
		| dd bs=32 count=1 >$@ 2>/dev/null

certs/apiserver_tokens.csv: $(AUTH_TOKEN)
	echo "$(shell cat $(AUTH_TOKEN)),admin,$(USERID),\"system:masters\"" > $@


certs/%.key:
	openssl genrsa -out $@ 2048

certs/etcd-server.crt: certs/etcd-server.csr certs/ca.crt certs/ca.key $(CERT_CONFIG)
	openssl x509 -req -in $< -CA certs/ca.crt -CAkey certs/ca.key \
		-CAcreateserial -out $@ -days $(CERTIFICATE_VALID_DAYS) \
		-extensions v3_etcd -extfile $(CERT_CONFIG)

certs/client.csr: certs/client.key $(CERT_CONFIG)
	openssl req -new -key $< -out $@ -subj "/CN=$(USERNAME)/O=system:masters"


certs/%.csr: certs/%.key $(CERT_CONFIG)
	openssl req -new -key $< -out $@ -config $(CERT_CONFIG)


certs/ca.crt: certs/ca.key $(CERT_CONFIG)
	openssl req -x509 -new -nodes -key $< -days $(CERTIFICATE_VALID_DAYS) \
		-out $@ -subj "/CN=$(MASTER_IP)"

certs/%.crt: certs/%.csr certs/ca.key certs/ca.crt $(CERT_CONFIG)
	openssl x509 -req -in $< -CA certs/ca.crt -CAkey certs/ca.key \
		-CAcreateserial -out $@ -days $(CERTIFICATE_VALID_DAYS) \
		-extensions v3_ext -extfile $(CERT_CONFIG)


certs: certs/apiserver_tokens.csv
certs: certs/ca.crt 
certs: certs/server.crt certs/server.key           # apiserver
certs: certs/etcd-client.crt certs/etcd-client.key # apiserver
certs: certs/etcd-server.crt certs/etcd-server.key # etcd
certs: certs/client.crt certs/client.key           # kubelet

cert-cleanup:
	rm -rvf certs/*.key certs/*.crt certs/*.csr $(CERT_CONFIG)


deployment-cleanup:
	 kubectl get deployment -n kubeception --no-headers -o name \
	 	| cut -d '/' -f 2 \
		| xargs -n 1 kubectl delete deployment -n kubeception

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
		--client-certificate=certs/client.crt \
		--client-key=certs/client.key \
		--token="$(shell cat $(AUTH_TOKEN))" \
		--embed-certs=true \
		--kubeconfig=$@
	kubectl config set-context kubeception \
		--user=kubeception_admin \
		--cluster=kubeception \
		--kubeconfig=$@
	kubectl config use-context kubeception --kubeconfig=$@

clean: cert-cleanup deployment-cleanup