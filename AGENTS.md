# AGENTS.md

Instructions for AI coding agents working in this repo.

## What this repo is

A template repo (`devopscoop/k0s-template`) for standing up one bare-metal Kubernetes cluster: k0s installed over SSH by k0sctl, with Flux intended for application delivery (no Flux manifests exist here yet). You create a cluster by copying this repo, editing `variables.sh`, and running `./deploy.sh`. There is no build, no test suite, and no lint config.

## Commands

```shell
./deploy.sh          # the entire workflow (see phases below)
bash -n deploy.sh    # syntax check
shellcheck deploy.sh # keep deploy.sh shellcheck-clean; it carries a `# shellcheck source=/dev/null` directive (shellcheck is not in the manifests)
yq . k0sctl.yaml     # confirm the YAML still parses after an edit
```

**Do not run `./deploy.sh` to test a change.** It rewrites files in the working tree, `git commit -n`s, `git push`es to origin, and then applies k0s to the real hosts named in `variables.sh`.

To talk to an already-deployed cluster:

```shell
export PATH="${PWD}/bin/linux-amd64:${PATH}"   # bin/${OS}-${ARCH}, where deploy.sh puts pinned binaries
export KUBECONFIG="${HOME}/.kube/${CLUSTER_NAME}"
```

## deploy.sh phases

`deploy.sh` is the only thing in the repo meant to be run (`variables.sh` is executable too, but it is sourced, not invoked). It is meant to be idempotent, `cd`s to its own directory, sources `variables.sh`, and runs with `set -Eexuo pipefail`. Four phases:

1. **Tool install** (`deploy.sh:33-86`). For each of kubectl, k0sctl, sops, and yq, compares the installed version against the pin in `variables.sh` and, on mismatch, downloads it into `bin/${OS}-${ARCH}` (prepended to `PATH`, gitignored) with a checksum check. yq's checksum uses `rhash` via the upstream `extract-checksum.sh`; the others use GNU `sha256sum`. This is why `rhash`, `wget`, and yq itself are prerequisites.
2. **De-templating** (`deploy.sh:88-103`). `sed`s every text file in the working tree containing `k0s-template` (excluding `.git` and `deploy.sh` itself) to `${CLUSTER_NAME}`, `git add`s them, then commits and pushes if anything changed. This is one-way: after the first run in a cluster repo, the string `k0s-template` survives only in `deploy.sh`. Don't add a literal `k0s-template` to a new file unless you want it substituted.
3. **Host generation** (`deploy.sh:105-145`). Resets `.spec.hosts = []` in `k0sctl.yaml` and rebuilds it with `yq` from `${CONTROLLER_HOSTS}` (role `controller+worker`, `--no-taints`) and `${WORKER_HOSTS}` (role `worker`), hardcoding SSH user `ubuntu` and key `~/.ssh/id_ed25519`. **Never hand-edit `spec.hosts`** — it is overwritten on every run. Hosts come from `variables.sh` only; the space-separated quoted strings exist because Bash can't export arrays. Then commits and pushes again.
4. **Apply** (`deploy.sh:147-148`). `k0sctl apply`, then writes the kubeconfig to `~/.kube/${CLUSTER_NAME}`.

## Where configuration lives

- `variables.sh` — cluster name, host lists, and the pinned versions of the tools deploy.sh installs.
- `k0sctl.yaml`, `spec.k0s.version` — the k0s/Kubernetes version of the cluster itself. This is distinct from `KUBERNETES_VERSION` in `variables.sh`, which only selects the kubectl download URL; the two are not kept in sync.
- `k0sctl.yaml`, `spec.k0s.config` — hand-maintained k0s `ClusterConfig`: Calico in `bird` (BGP) mode, dual-stack, pod/service CIDRs. Everything under `spec.k0s` is yours to edit; `spec.hosts` is not.

## Package manifests

This repo ships a `Brewfile` (macOS: `brew bundle`) and a `pkglist.txt` (Arch Linux) that install the prerequisites deploy.sh needs to run. Keep them in sync with the code:

- When you add a tool, script, or a new external command inside an existing script, add the package to BOTH files, with a comment noting what uses it.
- When a tool stops being used, remove it from both files.
- Do NOT add kubectl, k0sctl, or sops: deploy.sh self-installs pinned, checksum-verified copies into `./bin/` using the versions in `variables.sh`. If you add another self-installed tool to deploy.sh, keep it out of the manifests too — but make sure any tool the script invokes BEFORE its auto-install block runs is listed as a prerequisite (this is why yq is in the manifests).
- Verify package names before adding them: `brew info <formula>` for Homebrew, and the official repos/AUR for Arch. The Go (mikefarah) `yq` is Arch's `go-yq`; Arch's `yq` is the incompatible Python implementation. If a package is AUR-only, note that in pkglist.txt's header instructions.
- Update the "Install required packages" section in README.md if the tool list changes.

## GitHub Actions

Two Claude workflows, both pinned to `--model claude-opus-5 --effort xhigh` and to action SHAs. Keep both properties when editing them; the reasoning is in long comments in each file, which are worth reading before changing anything.

- `claude.yml` — tag mode, fires on `@claude` mentions. Bash stays disabled (no `--allowed-tools`), so the workflow pushes a branch and returns a prefilled PR link instead of opening the PR.
- `claude-code-review.yml` — agent mode, fires on PR open/synchronize/reopen/ready-for-review. Because it passes a `prompt`, its `--allowed-tools` allowlist is **required**, not optional: the inline-comment MCP server is only registered when the allowlist contains an `mcp__github_inline_comment__` entry, and without it the job reviews the code and posts nothing. The code-review plugin is deliberately not used here — `claude-code-action` ignores `ReportFindings`.

## Known rough edges in deploy.sh

Real, currently unfixed; don't be surprised by them, and don't treat them as intentional.

- The kubectl block compares against `KUBECTL_VERSION` but downloads `KUBERNETES_VERSION` (`deploy.sh:34-36`). With the current values (1.33.2 vs 1.33.1) the check can never match, so kubectl is re-downloaded on every run.
- The sops block `mv`s the download to `sops` and then `chmod`s the *old* filename (`deploy.sh:68-69`), which fails under `set -e` and aborts the script the first time that block runs. Nothing in the repo uses sops yet.
- `set -x` is still on deliberately; the TODO at the top of the script asks for it to be removed once someone has tested on macOS.

## Conventions

Recent commits use conventional-commit prefixes (`feat:`, `docs:`, `ci:`, `chore:`) and the maintainer's commits are GPG-signed. `deploy.sh` commits with `-n` on purpose, to skip the maintainer's local pre-commit hooks.
