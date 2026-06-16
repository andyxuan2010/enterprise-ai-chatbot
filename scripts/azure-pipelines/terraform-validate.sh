#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${script_dir}/terraform-common.sh"

terraform version
terraform fmt -check -recursive
terraform init -backend=false -reconfigure -input=false -no-color
timeout 10m terraform validate -no-color
