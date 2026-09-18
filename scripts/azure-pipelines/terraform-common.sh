#!/usr/bin/env bash

set -euo pipefail

configure_terraform_ci() {
  export TF_IN_AUTOMATION=true
  export TF_INPUT=0
  export CHECKPOINT_DISABLE=true
  export GIT_TERMINAL_PROMPT=0
}

configure_tf_data_dir() {
  if [[ -n "${TF_DATA_DIR:-}" ]]; then
    mkdir -p "${TF_DATA_DIR}"
  fi
}

is_resolved_pipeline_value() {
  local value="${1:-}"
  [[ -n "${value}" && "${value}" != \$\(* ]]
}

configure_app_service_custom_hostname_env() {
  if ! is_resolved_pipeline_value "${TF_VAR_app_service_custom_hostname:-}"; then
    if is_resolved_pipeline_value "${APP_SERVICE_CUSTOM_HOSTNAME:-}"; then
      export TF_VAR_app_service_custom_hostname="${APP_SERVICE_CUSTOM_HOSTNAME}"
    elif is_resolved_pipeline_value "${TF_VAR_APP_SERVICE_CUSTOM_HOSTNAME:-}"; then
      export TF_VAR_app_service_custom_hostname="${TF_VAR_APP_SERVICE_CUSTOM_HOSTNAME}"
    fi
  fi

  if ! is_resolved_pipeline_value "${TF_VAR_app_service_custom_hostname_ssl_state:-}"; then
    if is_resolved_pipeline_value "${APP_SERVICE_CUSTOM_HOSTNAME_SSL_STATE:-}"; then
      export TF_VAR_app_service_custom_hostname_ssl_state="${APP_SERVICE_CUSTOM_HOSTNAME_SSL_STATE}"
    elif is_resolved_pipeline_value "${TF_VAR_APP_SERVICE_CUSTOM_HOSTNAME_SSL_STATE:-}"; then
      export TF_VAR_app_service_custom_hostname_ssl_state="${TF_VAR_APP_SERVICE_CUSTOM_HOSTNAME_SSL_STATE}"
    fi
  fi
}

configure_azure_devops_git_auth() {
  if [[ -n "${SYSTEM_ACCESSTOKEN:-}" ]]; then
    git config --global http.https://dev.azure.com/.extraheader "AUTHORIZATION: bearer ${SYSTEM_ACCESSTOKEN}"
  fi
}

create_temp_tf_data_dir() {
  export TF_DATA_DIR
  TF_DATA_DIR="$(mktemp -d)"

  cleanup_tf_data_dir() {
    rm -rf "${TF_DATA_DIR}"
  }

  trap cleanup_tf_data_dir EXIT
}

configure_arm_auth() {
  export ARM_CLIENT_ID="${servicePrincipalId:?servicePrincipalId is required}"
  export ARM_TENANT_ID="${tenantId:?tenantId is required}"
  export ARM_SUBSCRIPTION_ID="$(az account show --query id -o tsv)"

  if [[ -n "${servicePrincipalKey:-}" ]]; then
    export ARM_CLIENT_SECRET="${servicePrincipalKey}"
  fi

  if [[ -n "${idToken:-}" ]]; then
    export ARM_USE_OIDC=true
    export ARM_OIDC_TOKEN="${idToken}"
  fi

  if [[ -n "${AZURESUBSCRIPTION_SERVICE_CONNECTION_ID:-}" ]]; then
    export ARM_OIDC_AZURE_SERVICE_CONNECTION_ID="${AZURESUBSCRIPTION_SERVICE_CONNECTION_ID}"
  fi
}

configure_terraform_ci
configure_app_service_custom_hostname_env
configure_azure_devops_git_auth
configure_tf_data_dir
