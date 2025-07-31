#!/usr/bin/env bash

# This script is idempotent, fails fast, and should be safe to run against a running cluster. It requires the variables.sh file.

# TODO: Remove x to disable debug output after someone with a Mac tests this script.
# https://vaneyckt.io/posts/safer_bash_scripts_with_set_euxo_pipefail/
set -Eexuo pipefail

# https://stackoverflow.com/questions/59895/how-do-i-get-the-directory-where-a-bash-script-is-located-from-within-the-script
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# Need to cd to this dir, because there are a lot of git commands in this
# script that expect to be run from this directory.
cd "${SCRIPT_DIR}"

# Setting upstream so we can easily update from k0s-template
# git remote remove upstream || true
# git remote add upstream git@gitlab.com:devopscoop/k0s-template.git

# Telling shellcheck to stop whining...
# shellcheck source=/dev/null
source variables.sh

export KUBECONFIG="${HOME}/.kube/${CLUSTER_NAME}"

# Set the path for the binaries for the environment running this
OS="$(uname -o | tr '[:upper:]' '[:lower:]' | sed -e 's%^gnu/%%')"
ARCH="$(uname -m | sed -e 's/x86_64/amd64/g')"
BIN_DIR="${SCRIPT_DIR}/bin/${OS}-${ARCH}"
mkdir -p "${BIN_DIR}"
export PATH="${BIN_DIR}:${PATH}"

# Check for "kubectl" runtime or install it
if [[ "$(kubectl version --client=true -o yaml | yq .clientVersion.gitVersion)" != "v${KUBECTL_VERSION}" ]]; then
  # install packaged binaries for this arch
  curl -sLo "${BIN_DIR}/kubectl" "https://dl.k8s.io/release/v${KUBERNETES_VERSION}/bin/${OS}/${ARCH}/kubectl"
  curl -sLo "${BIN_DIR}/kubectl.sha256" "https://dl.k8s.io/release/v${KUBERNETES_VERSION}/bin/${OS}/${ARCH}/kubectl.sha256"
  cd "${BIN_DIR}"
  echo "$(cat kubectl.sha256) kubectl" | sha256sum --check
  rm -f kubectl.sha256
  chmod ugo+rx kubectl
  cd -
fi

# Check for "k0sctl" runtime or install it
# https://github.com/k0sproject/k0sctl/releases/
if [[ "$(k0sctl version | grep '^version:' | yq .version)" != "v${K0SCTL_VERSION}" ]] ; then
  # install packaged binaries for this arch
  curl -sLo "${BIN_DIR}/k0sctl-${OS}-${ARCH}" "https://github.com/k0sproject/k0sctl/releases/download/v${K0SCTL_VERSION}/k0sctl-${OS}-${ARCH}"
  curl -sLo "${BIN_DIR}/checksums.txt" "https://github.com/k0sproject/k0sctl/releases/download/v${K0SCTL_VERSION}/checksums.txt"
  cd "${BIN_DIR}"
  sha256sum -c <(grep "k0sctl-${OS}-${ARCH}" checksums.txt)
  rm -f checksums.txt
  mv -f "k0sctl-${OS}-${ARCH}" k0sctl
  chmod ugo+rx k0sctl
  cd -
fi

# Check for "sops" runtime or install it
# https://github.com/getsops/sops/releases/
if [[ "$(sops --version | grep -e '^sops' | awk '{print $2}')" != "${SOPS_VERSION}" ]] ; then
  curl -sLo "${BIN_DIR}/sops-v${SOPS_VERSION}.checksums.txt" "https://github.com/getsops/sops/releases/download/v${SOPS_VERSION}/sops-v${SOPS_VERSION}.checksums.txt"
  curl -sLo "${BIN_DIR}/sops-v${SOPS_VERSION}.${OS}.${ARCH}" "https://github.com/getsops/sops/releases/download/v${SOPS_VERSION}/sops-v${SOPS_VERSION}.${OS}.${ARCH}"
  cd "${BIN_DIR}"
  FILENAME="sops-v${SOPS_VERSION}.${OS}.${ARCH}"
  sha256sum -c <(grep "${FILENAME}" "sops-v${SOPS_VERSION}.checksums.txt")
  rm -f "sops-v${SOPS_VERSION}.checksums.txt"
  mv "${FILENAME}" sops
  chmod ugo+rx "${FILENAME}"
  cd -
fi

# Check for "yq" runtime or install it
# https://github.com/mikefarah/yq/releases
if [[ "$(yq --version | awk '{ print $4 }')" != "v${YQ_VERSION}" ]] ; then
  cd "${BIN_DIR}"
  wget --no-verbose "https://github.com/mikefarah/yq/releases/download/v${YQ_VERSION}/yq_${OS}_${ARCH}.tar.gz" -O - | tar xz
  wget --no-verbose "https://github.com/mikefarah/yq/releases/download/v${YQ_VERSION}/checksums"
  wget --no-verbose "https://github.com/mikefarah/yq/releases/download/v${YQ_VERSION}/checksums_hashes_order"
  wget --no-verbose "https://github.com/mikefarah/yq/releases/download/v${YQ_VERSION}/extract-checksum.sh"
  chmod +x extract-checksum.sh
  ./extract-checksum.sh SHA-256 "yq_${OS}_${ARCH}" | rhash -c -
  mv "yq_${OS}_${ARCH}" yq
  rm -v checksums checksums_hashes_order extract-checksum.sh
  cd -
fi

# Replace k0s-template with CLUSTER_NAME in all files except this script.
# Have to use -i.bak because Mac sed is garbage.
while read -r f; do
  sed -i.bak "s/k0s-template/${CLUSTER_NAME}/g" "${f}"
  rm "${f}.bak"
  git add "${f}"
done < <(grep -rIl k0s-template --exclude-dir .git --exclude deploy.sh .)

# This if statement is needed for idempotency. Don't commit and push if there are no changes.
if ! git diff HEAD --quiet; then

  # Using -n so that SOME PEOPLE'S pre-commit hooks don't freak out and break things. Talking about myself here. I have a large collection of hooks.
  git commit -nm "Replacing k0s-template with ${CLUSTER_NAME}"

  git push
fi

yq -i '.spec.hosts = []' k0sctl.yaml

# I tried to use a Bash array, like "${HOSTS[@]}" and learned that you cannot export arrays. Don't be dumb like me.
# https://stackoverflow.com/questions/5564418/exporting-an-array-in-bash-script
for host in $CONTROLLER_HOSTS; do
  yq -i ".spec.hosts +=
    [
      {
        \"ssh\": {
          \"address\": \"${host}\",
          \"user\": \"ubuntu\",
          \"keyPath\": \"${HOME}/.ssh/id_ed25519\"
        },
        \"role\": \"controller+worker\",
        \"installFlags\": [
          \"--no-taints\"
        ]
      }
    ]
  " k0sctl.yaml
done
for host in $WORKER_HOSTS; do
  yq -i ".spec.hosts +=
    [
      {
        \"ssh\": {
          \"address\": \"${host}\",
          \"user\": \"ubuntu\",
          \"keyPath\": \"${HOME}/.ssh/id_ed25519\"
        },
        \"role\": \"worker\"
      }
    ]
  " k0sctl.yaml
done

git add k0sctl.yaml
if ! git diff HEAD --quiet; then
  git commit -nm "Updating k0sctl.yaml"
  git push
fi

k0sctl apply --config k0sctl.yaml
k0sctl kubeconfig > "${KUBECONFIG}"
