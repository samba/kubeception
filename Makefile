
DEPLOYMENT_YAML := .tmp/deployment.yaml
SOURCE_YAML := $(shell ls -1 ./manifest/*.yaml)
CERTIFICATE_VALID_DAYS := 30000

MASTER_IP := 10.0.0.1
MASTER_CLUSTER_IP := 10.0.0.1

CLUSTER_NAME := kubeception
CERT_CONFIG := certs/cluster.$(CLUSTER_NAME).conf

export CLUSTER_NAME MASTER_IP MASTER_CLUSTER_IP

.PHONY: up down deploy test

up:
	minikube status | grep -i stopped || exit 0
	minikube start

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



# Certificate preparation
# cf https://kubernetes.io/docs/concepts/cluster-administration/certificates/

$(CERT_CONFIG): certs/csr.conf scripts/setup_certs.sh
	# mkdir -p "$(dir $(CERT_CONFIG))/$(CLUSTER_NAME)"
	bash scripts/setup_certs.sh $< > $@

certs/%.key:
	openssl genrsa -out $@ 2048

certs/%.csr: certs/%.key | $(CERT_CONFIG)
	openssl req -new -key $< -out $@ -config $(CERT_CONFIG)

certs/ca.crt: certs/ca.key | $(CERT_CONFIG)
	openssl req -x509 -new -nodes -key $< -days $(CERTIFICATE_VALID_DAYS) \
		-out $@ -subj "/CN=$(MASTER_IP)"

certs/%.crt: certs/%.csr certs/ca.key certs/ca.crt | $(CERT_CONFIG)
	openssl x509 -req -in $< -CA certs/ca.crt -CAkey certs/ca.key \
		-CAcreateserial -out $@ -days $(CERTIFICATE_VALID_DAYS) \
		-extensions v3_ext -extfile $(CERT_CONFIG)


certs: certs/ca.crt certs/server.crt certs/server.key certs/etcd-client.crt certs/etcd-server.crt certs/etcd-server.key certs/etcd-client.key

cert-cleanup:
	rm -rvf certs/*.key certs/*.crt certs/*.csr $(CERT_CONFIG)
