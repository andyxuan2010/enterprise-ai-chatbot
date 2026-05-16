#!/usr/bin/env bash
set -euo pipefail

if [[ -f /home/site/wwwroot/antenv/bin/activate ]]; then
  # Oryx-created virtual environment for App Service Python builds.
  source /home/site/wwwroot/antenv/bin/activate
fi

exec python -m uvicorn main:app --host 0.0.0.0 --port "${PORT:-8000}"
