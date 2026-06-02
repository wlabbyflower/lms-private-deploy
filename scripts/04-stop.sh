#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ROOT}/lms.env"
TUTOR="${ROOT}/.venv-tutor/bin/tutor"
source "${ROOT}/scripts/lib-docker-group.sh"

ensure_docker_access "$@"

docker compose --env-file "${ENV_FILE}" -f "${ROOT}/moodle/docker-compose.yml" down

if [ -x "${TUTOR}" ]; then
  TUTOR_ROOT="${ROOT}/openedx/tutor-root" "${TUTOR}" local stop
fi
