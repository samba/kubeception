
DEPLOYMENT_YAML := .tmp/deployment.yaml
SOURCE_YAML := $(shell ls -1 ./manifest/*.yaml)

.PHONY: up down deploy test

up:
	minikube status | grep -i stopped || exit 0
	minikube start

down:
	minikube stop	

.tmp:
	mkdir -p $@

$(DEPLOYMENT_YAML): $(SOURCE_YAML)
	cat $< > $@

.tmp/deployment.ts:  $(DEPLOYMENT_YAML)
	bash scripts/deploy-local.sh $<
	touch $@

deploy:  .tmp/deployment.ts 

test: deploy
	echo "TODO: test the deployment."

