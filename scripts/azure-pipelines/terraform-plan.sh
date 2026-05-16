#!/usr/bin/env bash

set -euo pipefail

backend_file="${1:?backend file path is required}"
var_file="${2:?variable file path is required}"
plan_file="${3:?plan file path is required}"
plan_text_file="${4:?plan text file path is required}"

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${script_dir}/terraform-common.sh"
configure_arm_auth

mkdir -p "$(dirname "${plan_file}")"
mkdir -p "$(dirname "${plan_text_file}")"

terraform version
terraform init -reconfigure -input=false -no-color -backend-config="${backend_file}"
terraform plan -input=false -no-color -var-file="${var_file}" -out="${plan_file}"
terraform show -no-color "${plan_file}" > "${plan_text_file}"
bash "${script_dir}/../github/terraform-change-summary.sh" "${plan_file}" "Terraform plan summary"
