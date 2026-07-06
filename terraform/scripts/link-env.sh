#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

link() { ln -sfn "$2" "$1"; }

link_stack() {
  local stack="$1"
  local env_rel="$2"
  local dir="${ROOT}/infra/${stack}"
  [[ -d "${dir}" ]] || return 0
  link "${dir}/common.auto.tfvars"  "${env_rel}/common.tfvars"
  link "${dir}/common.variables.tf" "${env_rel}/common.variables.tf"
  link "${dir}/providers.tf"        "${env_rel}/providers.tf"
  echo "linked ${stack}: env"
}

link_deep_stack() {
  local parent="$1"
  local stack="$2"
  local secrets_file="${3:-}"
  local dir="${ROOT}/infra/${parent}/${stack}"
  [[ -d "${dir}" ]] || return 0
  link "${dir}/common.auto.tfvars"  "../../../env/common.tfvars"
  link "${dir}/common.variables.tf" "../../../env/common.variables.tf"
  link "${dir}/providers.tf"        "../../../env/providers.tf"
  if [[ -n "${secrets_file}" ]]; then
    link "${dir}/${stack}.auto.tfvars" "../../../env/${secrets_file}"
  fi
  echo "linked ${parent}/${stack}"
}

# top-level stacks
link_stack "base"    "../../env"
link_stack "network" "../../env"
link_stack "aks"     "../../env"

# dbs/*
link_deep_stack "dbs" "postgresql" "postgresql.tfvars"
link_deep_stack "dbs" "redis"      "redis.tfvars"
link_deep_stack "dbs" "servicebus" "servicebus.tfvars"

# security/*
link_deep_stack "security" "identity"
link_deep_stack "security" "keyvault" "keyvault.tfvars"
link_deep_stack "security" "acr"      "acr.tfvars"

# remote state — shallow (infra/<stack>/)
for stack in network aks; do
  dir="${ROOT}/infra/${stack}"
  [[ -d "${dir}" ]] || continue
  link "${dir}/_remote.base.tf" "../../shared/remote_state/base.tf"
  echo "linked ${stack}: _remote.base"
done

link "${ROOT}/infra/aks/_remote.network.tf" "../../shared/remote_state/network.shallow.tf"
link "${ROOT}/infra/aks/_remote.identity.tf" "../../shared/remote_state/identity.aks.tf"
link "${ROOT}/infra/aks/_remote.acr.tf" "../../shared/remote_state/acr.aks.tf"
echo "linked aks: network + identity + acr"

# remote state — dbs (infra/dbs/<stack>/)
for stack in postgresql redis servicebus; do
  dir="${ROOT}/infra/dbs/${stack}"
  [[ -d "${dir}" ]] || continue
  link "${dir}/_remote.base.tf"    "../../../shared/remote_state/base.deep.tf"
  link "${dir}/_remote.network.tf" "../../../shared/remote_state/network.deep.tf"
  echo "linked dbs/${stack}: remote_state"
done

# remote state — security (infra/security/<stack>/)
for stack in identity keyvault acr; do
  dir="${ROOT}/infra/security/${stack}"
  [[ -d "${dir}" ]] || continue
  link "${dir}/_remote.base.tf"    "../../../shared/remote_state/base.security.tf"
  link "${dir}/_remote.network.tf" "../../../shared/remote_state/network.security.tf"
  echo "linked security/${stack}: base + network"
done

link "${ROOT}/infra/security/keyvault/_remote.identity.tf" "../../../shared/remote_state/identity.sibling.tf"
echo "linked security/keyvault: identity"

# cleanup legacy
rm -f "${ROOT}/infra/security/_remote.base.tf" \
      "${ROOT}/infra/security/common.auto.tfvars" \
      "${ROOT}/infra/security/common.variables.tf" \
      "${ROOT}/infra/security/providers.tf" 2>/dev/null || true
find "${ROOT}/infra" -name 'remote_state*.tf' -type l -delete 2>/dev/null || true

ensure_tfvars() {
  local example="$1" target="$2"
  if [[ ! -f "${target}" && -f "${example}" ]]; then
    cp "${example}" "${target}"
    echo "created ${target}"
  fi
}

ensure_tfvars "${ROOT}/env/common.tfvars.example"       "${ROOT}/env/common.tfvars"
ensure_tfvars "${ROOT}/env/postgresql.tfvars.example"  "${ROOT}/env/postgresql.tfvars"
ensure_tfvars "${ROOT}/env/redis.tfvars.example"       "${ROOT}/env/redis.tfvars"
ensure_tfvars "${ROOT}/env/servicebus.tfvars.example"  "${ROOT}/env/servicebus.tfvars"
ensure_tfvars "${ROOT}/env/keyvault.tfvars.example"    "${ROOT}/env/keyvault.tfvars"
ensure_tfvars "${ROOT}/env/acr.tfvars.example"         "${ROOT}/env/acr.tfvars"
