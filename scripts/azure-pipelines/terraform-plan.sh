#!/usr/bin/env bash

set -euo pipefail

backend_subscription_id="${1:?backend subscription id is required}"
backend_tenant_id="${2:?backend tenant id is required}"
backend_resource_group_name="${3:?backend resource group name is required}"
backend_storage_account_name="${4:?backend storage account name is required}"
backend_container_name="${5:?backend container name is required}"
backend_key="${6:?backend key is required}"
var_file="${7:?variable file path is required}"
plan_file="${8:?plan file path is required}"
plan_text_file="${9:?plan text file path is required}"

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${script_dir}/terraform-common.sh"
configure_arm_auth

mkdir -p "$(dirname "${plan_file}")"
mkdir -p "$(dirname "${plan_text_file}")"

terraform version
terraform init \
  -reconfigure \
  -input=false \
  -no-color \
  -backend-config="subscription_id=${backend_subscription_id}" \
  -backend-config="tenant_id=${backend_tenant_id}" \
  -backend-config="resource_group_name=${backend_resource_group_name}" \
  -backend-config="storage_account_name=${backend_storage_account_name}" \
  -backend-config="container_name=${backend_container_name}" \
  -backend-config="key=${backend_key}"
terraform plan -input=false -no-color -lock-timeout=10m -var-file="${var_file}" -out="${plan_file}"
terraform show -no-color "${plan_file}" > "${plan_text_file}"
summary_text="$(bash "${script_dir}/../github/terraform-change-summary.sh" "${plan_file}" "Terraform plan summary")"
printf '%s\n' "${summary_text}"

summary_file="$(dirname "${plan_text_file}")/terraform-plan-summary.md"
{
  printf '## Terraform plan summary\n\n'
  printf '```text\n'
  printf '%s\n' "${summary_text}"
  printf '```\n'
} > "${summary_file}"
echo "##vso[task.uploadsummary]${summary_file}"
