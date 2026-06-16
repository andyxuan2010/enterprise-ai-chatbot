#!/usr/bin/env bash

set -euo pipefail

terraform_version="${1:?terraform version is required}"
os="linux"
arch="$(uname -m)"
install_root="${AGENT_TEMPDIRECTORY:-${RUNNER_TEMP:-/tmp}}/terraform-bin"

case "${arch}" in
  x86_64)
    arch="amd64"
    ;;
  aarch64|arm64)
    arch="arm64"
    ;;
  *)
    echo "Unsupported architecture: ${arch}" >&2
    exit 1
    ;;
esac

temp_dir="$(mktemp -d)"
trap 'rm -rf "${temp_dir}"' EXIT

zip_path="${temp_dir}/terraform.zip"
download_url="https://releases.hashicorp.com/terraform/${terraform_version}/terraform_${terraform_version}_${os}_${arch}.zip"

mkdir -p "${install_root}"
curl -fsSL "${download_url}" -o "${zip_path}"
unzip -oq "${zip_path}" -d "${temp_dir}"
install -m 0755 "${temp_dir}/terraform" "${install_root}/terraform"

echo "##vso[task.prependpath]${install_root}"

"${install_root}/terraform" version
