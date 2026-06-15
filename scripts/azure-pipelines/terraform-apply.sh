#!/usr/bin/env bash

set -euo pipefail

backend_subscription_id="${1:?backend subscription id is required}"
backend_tenant_id="${2:?backend tenant id is required}"
backend_resource_group_name="${3:?backend resource group name is required}"
backend_storage_account_name="${4:?backend storage account name is required}"
backend_container_name="${5:?backend container name is required}"
backend_key="${6:?backend key is required}"
plan_file="${7:?plan file path is required}"

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${script_dir}/terraform-common.sh"
configure_arm_auth

if [[ ! -f "${plan_file}" ]]; then
  echo "Terraform plan file not found: ${plan_file}" >&2
  exit 1
fi

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
terraform apply -input=false -no-color -lock-timeout=10m -auto-approve "${plan_file}"
summary_text="$(bash "${script_dir}/../github/terraform-change-summary.sh" "${plan_file}" "Terraform apply summary")"
printf '%s\n' "${summary_text}"

summary_file="$(dirname "${plan_file}")/terraform-apply-summary.md"
{
  printf '## Terraform apply summary\n\n'
  printf '```text\n'
  printf '%s\n' "${summary_text}"
  printf '```\n'
} > "${summary_file}"
echo "##vso[task.uploadsummary]${summary_file}"
