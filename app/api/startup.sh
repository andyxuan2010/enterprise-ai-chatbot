#!/usr/bin/env bash
set -euo pipefail

app_root="${APP_PATH:-$(pwd)}"
if [[ -d "${app_root}/app/api" ]]; then
  cd "${app_root}/app/api"
fi

exec python -m uvicorn main:app --host 0.0.0.0 --port "${PORT:-8000}"
