# lima-k3s-node

A reproducible NixOS + [k3s](https://k3s.io/) VM, run via [Lima](https://lima-vm.io/).

The point of this repo: `limactl start` alone only gets you a bare NixOS
image. The actual system state — packages, the k3s service, firewall rules —
is declared in [`nixos/flake.nix`](nixos/flake.nix) and
[`nixos/configuration.nix`](nixos/configuration.nix), and
[`nixos/flake.lock`](nixos/flake.lock) pins every input to an exact commit.
As long as `flake.lock` doesn't change, applying this flake produces a
bit-identical system every time, on any host.

## Prerequisites (macOS)

```bash
# Homebrew itself, if not already installed: https://brew.sh
brew install lima
```

That installs `limactl` and everything Lima needs for the default `vz`
driver (Apple's Virtualization framework), which is what this template uses.

- **macOS 13.5 or later** is required for the `vz` driver.
- **git** is needed (Nix flakes require the flake directory to be
  git-tracked). It ships with the Xcode Command Line Tools — install with
  `xcode-select --install` if `git --version` fails.
- **QEMU is not required** for the default setup. Only install it
  (`brew install qemu`) if you need to run an architecture that doesn't
  match your Mac (e.g. x86_64 on Apple Silicon) or run this on Linux, where
  `vz` isn't available and Lima falls back to QEMU.
- **Internet access** for the first bootstrap: it downloads the NixOS
  package closure and k3s (~100+ MiB from `cache.nixos.org`). If you're on a
  VPN, some setups interfere with the VM's own networking during boot —
  disable it if `limactl shell` hangs or times out.
- **Disk space**: the base image's disk is a sparse 100GiB file (not fully
  allocated); actual usage is a few GiB.

## Quick start

```bash
git clone <this-repo-url>
cd lima-k3s-node
./bootstrap.sh
```

This creates a Lima instance named `k8s`, applies the flake, reboots into it,
and waits for k3s to report a node. Get a kubeconfig with:

```bash
limactl shell k8s sudo cat /etc/rancher/k3s/k3s.yaml > kubeconfig.yaml
KUBECONFIG=kubeconfig.yaml kubectl get nodes
```

## Creating another identical VM

Locally, under a different name:

```bash
./bootstrap.sh my-second-node
```

On another host or user: clone this repo there and run `./bootstrap.sh`.
`bootstrap.sh` resolves the flake path relative to its own location, so no
path editing is needed — as long as `flake.lock` is unchanged, you get the
exact same package versions as everywhere else this repo is bootstrapped.

If you ever need to point at a flake that lives somewhere else inside the
guest, pass it explicitly: `./bootstrap.sh <instance-name> <path-to-nixos-dir>`.

## Updating the pinned versions

`flake.lock` is what makes this reproducible — don't update it casually.
When you do want newer packages:

```bash
limactl start --mount-writable --name=k8s ./k8s.yaml   # only needed once, to allow writing flake.lock
limactl shell k8s -- nix --extra-experimental-features 'nix-command flakes' flake update /path/to/nixos
./bootstrap.sh k8s
git add nixos/flake.lock && git commit -m "Update pinned nixpkgs/nixos-lima"
```

## Notes on the defaults

- `security.sudo.wheelNeedsPassword = false` and k3s's
  `--tls-san=127.0.0.1/localhost` flags assume a local, single-user dev VM.
  Change both before exposing this to a network or other users.
- Running several instances from this template at once needs distinct host
  ports in `k8s.yaml`'s `portForwards` (80/443/6443 by default) to avoid
  bind conflicts.
