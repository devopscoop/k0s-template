# Brewfile for k0s-template
#
# Installs every CLI tool used or referenced by this repo.
# Usage: brew bundle
#
# Note: deploy.sh downloads its own pinned kubectl, k0sctl, and sops binaries
# into ./bin/ (versions from variables.sh, checksum-verified), so those are
# deliberately NOT in this manifest. The tools below are the prerequisites
# deploy.sh itself needs to run.

# bash - deploy.sh and variables.sh use `#!/usr/bin/env bash`
brew "bash"

# coreutils - deploy.sh uses GNU `sha256sum`, which macOS lacks. Homebrew
# installs it as `gsha256sum` unless the coreutils gnubin directory is on PATH.
brew "coreutils"

# curl - downloads the pinned kubectl/k0sctl/sops binaries and checksums
brew "curl"

# git - deploy.sh commits and pushes cluster config changes
brew "git"

# rhash - verifies the yq download checksum
brew "rhash"

# wget - downloads the yq tarball and checksums
brew "wget"

# yq - Go (mikefarah) yq; parses versions and rewrites k0sctl.yaml. Must be
# pre-installed: deploy.sh invokes yq before its own yq auto-install runs.
brew "yq"
