#!/usr/bin/env bash

set -xeuf -o pipefail

export MASTER_IP=${MASTER_IP:-10.0.0.1}
export MASTER_CLUSTER_IP=${MASTER_CLUSTER_IP:-${MASTER_IP}}

# Prints modified output to stdout... for use in Makefile
sed \
    -e "s@<country>@${CERT_COUNTRY:-US}@" \
    -e "s@<state>@${CERT_STATE:-OR}@" \
    -e "s@<city>@${CERT_CITY:-Portland}@" \
    -e "s@<organization>@${CERT_ORG:-Unknown Organization}@" \
    -e "s@<organization unit>@${CERT_OU:-Unknown Unit}@" \
    -e "s@<MASTER_IP>@${MASTER_IP}@" \
    -e "s@<MASTER_CLUSTER_IP>@${MASTER_CLUSTER_IP}@" \
    -e "s@<CLUSTER_NAME>@${CLUSTER_NAME:-clustername}@" \
    -e "s@<ETCD_SERVICE>@${ETCD_SERVICE:-etcdservice}@" \
    "$@"



