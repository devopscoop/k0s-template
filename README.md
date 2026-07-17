# k0s-template

## Overview

This is a template repo that can be used to create a bare-metal Kubernetes cluster. We use k0s to build a cluster, and Flux to deploy applications.

## Install required packages

deploy.sh downloads its own pinned `kubectl`, `k0sctl`, and `sops` binaries into `./bin/` (versions from `variables.sh`, checksum-verified), but it needs some tools pre-installed to do that: `bash`, `curl`, `git`, `rhash`, `wget`, and the Go (mikefarah) `yq`. Package manifests are included:

- macOS, using [Homebrew](https://brew.sh/) and the `Brewfile`:

  ```shell
  brew bundle
  ```

  Note: deploy.sh uses GNU `sha256sum`; the Brewfile installs `coreutils`, but you must put its gnubin directory on your PATH (macOS support is untested — see the TODO in deploy.sh).

- Arch Linux, using the `pkglist.txt` (all packages are in the official repos):

  ```shell
  grep -vE '^(#|$)' pkglist.txt | sudo pacman -S --needed -
  ```

On other operating systems, install the tools listed above manually. Note that on Arch the Go `yq` package is named `go-yq` — the `yq` package is the incompatible Python implementation.
