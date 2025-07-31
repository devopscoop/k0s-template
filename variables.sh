#!/usr/bin/env bash

export CLUSTER_NAME="6j0-org-dev"

# HOSTS must be a space-separated, quoted string containing the FQDN of all the hosts that we're adding to the k0s cluster.
export CONTROLLER_HOSTS="host1.6j0.org host2.6j0.org host3.6j0.org"
export WORKER_HOSTS=""

# Tool versions
export K0SCTL_VERSION="0.25.1"
export KUBECTL_VERSION="1.33.2"
export KUBERNETES_VERSION="1.33.1"
export SOPS_VERSION="3.10.2"
export YQ_VERSION="4.45.4"
