#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ROOT}/lms.env"
COMPOSE_FILE="${ROOT}/moodle/docker-compose.yml"
source "${ROOT}/scripts/lib-docker-group.sh"

if ! command -v docker >/dev/null 2>&1; then
  echo "docker is not installed. Run: ${ROOT}/scripts/00-install-docker.sh" >&2
  exit 1
fi

ensure_docker_access "$@"

set -a
source "${ENV_FILE}"
set +a

docker compose --env-file "${ENV_FILE}" -f "${COMPOSE_FILE}" pull
docker compose --env-file "${ENV_FILE}" -f "${COMPOSE_FILE}" up -d

cat <<EOF

Moodle is starting. First boot can take several minutes.

URL:
  http://${MOODLE_HOST}:${MOODLE_HTTP_PORT}

Admin:
  ${MOODLE_ADMIN_USER}

Password is stored in:
  ${ENV_FILE}

Check status:
  docker compose --env-file "${ENV_FILE}" -f "${COMPOSE_FILE}" ps
EOF
