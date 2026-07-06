#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STACK="${1:?Usage: tf.sh <stack> [terraform command...]}"
shift

STACK_DIR="${ROOT}/infra/${STACK}"

if [[ ! -d "${STACK_DIR}" ]]; then
  echo "Unknown stack: ${STACK}" >&2
  exit 1
fi

if [[ ! -f "${ROOT}/env/common.tfvars" ]]; then
  echo "Missing env/common.tfvars — run: bash scripts/link-env.sh" >&2
  exit 1
fi

cd "${STACK_DIR}"

if [[ $# -eq 0 ]]; then
  set -- plan
fi

terraform "$@"
