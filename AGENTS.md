# AGENTS.md

Instructions for AI coding agents working in this repo.

## Package manifests

This repo ships a `Brewfile` (macOS: `brew bundle`) and a `pkglist.txt` (Arch Linux) that install the prerequisites deploy.sh needs to run. Keep them in sync with the code:

- When you add a tool, script, or a new external command inside an existing script, add the package to BOTH files, with a comment noting what uses it.
- When a tool stops being used, remove it from both files.
- Do NOT add kubectl, k0sctl, or sops: deploy.sh self-installs pinned, checksum-verified copies into `./bin/` using the versions in `variables.sh`. If you add another self-installed tool to deploy.sh, keep it out of the manifests too — but make sure any tool the script invokes BEFORE its auto-install block runs is listed as a prerequisite (this is why yq is in the manifests).
- Verify package names before adding them: `brew info <formula>` for Homebrew, and the official repos/AUR for Arch. The Go (mikefarah) `yq` is Arch's `go-yq`; Arch's `yq` is the incompatible Python implementation. If a package is AUR-only, note that in pkglist.txt's header instructions.
- Update the "Install required packages" section in README.md if the tool list changes.
