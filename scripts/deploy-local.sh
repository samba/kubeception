#!/usr/bin/env bash

set -x
set -euf -o pipefail

# Inner cluster's system secrets are now managed by `host-secrets` rule in Makefile.

# Install all manifest components (command line arguments).
for f_yaml; do
  kubectl apply -f ${f_yaml} || exit $?
done

