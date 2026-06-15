#!/usr/bin/env bash

set -euo pipefail

backend_file="${1:-backend.tf}"

if [[ ! -f "${backend_file}" ]]; then
  echo "Backend file not found: ${backend_file}" >&2
  exit 1
fi

python3 - "${backend_file}" <<'PY'
import re
import sys
from pathlib import Path

backend_file = Path(sys.argv[1])
text = backend_file.read_text(encoding="utf-8")

match = re.search(r'backend\s+"azurerm"\s*\{(?P<body>.*?)\n\s*\}', text, re.S)
body = match.group("body") if match else text
mapping = {
    "subscription_id": "backendSubscriptionId",
    "tenant_id": "backendTenantId",
    "resource_group_name": "backendResourceGroupName",
    "storage_account_name": "backendStorageAccountName",
    "container_name": "backendContainerName",
    "key": "backendKey",
}

missing = []
values = {}
for hcl_name, ado_name in mapping.items():
    value_match = re.search(rf'^\s*{re.escape(hcl_name)}\s*=\s*"([^"]+)"\s*$', body, re.M)
    if not value_match:
        missing.append(hcl_name)
    else:
        values[ado_name] = value_match.group(1)

if missing:
    print(
        f"Missing required backend values in {backend_file}: {', '.join(missing)}",
        file=sys.stderr,
    )
    sys.exit(1)

for ado_name, value in values.items():
    print(f"##vso[task.setvariable variable={ado_name}]{value}")
    print(f"{ado_name}={value}")
PY
