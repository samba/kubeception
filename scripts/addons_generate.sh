#!/usr/bin/env bash

set -euf -o pipefail

strip_vars () {
    sed -e 's@CLUSTER_DOMAIN@cluster.local@g;' \
        -e 's/clusterIP: CLUSTER_DNS_IP/type: ClusterIP/;' \
        -e 's@REVERSE_CIDRS@in-addr.arpa ip6.arpa@'
}

fetch_urls () {
    echo "---"  # begin a YAML document
    egrep 'https?:' - | while read url; do 
        curl -s -o - "${url}"; # read out the URL's content only
        echo "---" # end a YAML document
    done
}


fetch_urls | strip_vars
