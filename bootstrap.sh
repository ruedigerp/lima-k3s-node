#!/bin/bash
# One-time step that turns a bare nixos-lima VM into the k3s node defined by
# ./nixos/flake.nix. Safe to re-run: `nixos-rebuild boot` is idempotent and only
# changes anything when the flake (or its pinned inputs) actually changed.
#
# Usage: ./bootstrap.sh [instance-name] [flake-dir-as-seen-inside-the-guest]
set -euo pipefail

NAME="${1:-k8s}"
FLAKE_DIR="${2:-$(cd "$(dirname "${BASH_SOURCE[0]}")/nixos" && pwd)}"

limactl start --tty=false --name="${NAME}" ./k8s.yaml

ARCH="$(limactl shell "${NAME}" -- uname -m)"
case "${ARCH}" in
  aarch64) ATTR=k3s-node-aarch64 ;;
  x86_64)  ATTR=k3s-node-x86_64 ;;
  *) echo "unsupported arch: ${ARCH}" >&2; exit 1 ;;
esac

echo "Applying ${FLAKE_DIR}#${ATTR} to instance '${NAME}'..."
limactl shell "${NAME}" -- sudo nixos-rebuild boot --flake "${FLAKE_DIR}#${ATTR}"

echo "Restarting '${NAME}' to boot into the new configuration..."
limactl stop "${NAME}"
limactl start "${NAME}"

echo "Waiting for k3s to come up..."
limactl shell "${NAME}" -- bash -c 'until sudo test -f /etc/rancher/k3s/k3s.yaml; do sleep 2; done'
limactl shell "${NAME}" -- sudo kubectl --kubeconfig=/etc/rancher/k3s/k3s.yaml get nodes
