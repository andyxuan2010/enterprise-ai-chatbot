#!/usr/bin/env bash

set -euo pipefail

backend_file="${1:?backend file path is required}"
plan_file="${2:?plan file path is required}"

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${script_dir}/terraform-common.sh"
configure_arm_auth

if [[ ! -f "${plan_file}" ]]; then
  echo "Terraform plan file not found: ${plan_file}" >&2
  exit 1
fi

terraform version
terraform init -reconfigure -input=false -no-color -backend-config="${backend_file}"
terraform apply -input=false -no-color -auto-approve "${plan_file}"
bash "${script_dir}/../github/terraform-change-summary.sh" "${plan_file}" "Terraform apply summary"
