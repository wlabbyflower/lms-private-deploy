#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ROOT}/lms.env"
TUTOR="${ROOT}/.venv-tutor/bin/tutor"
source "${ROOT}/scripts/lib-i18n.sh"
lms_load_env_language "${ENV_FILE}"
source "${ROOT}/scripts/lib-docker-group.sh"

ensure_docker_access "$@"

if [ ! -f "${ENV_FILE}" ]; then
  lms_msg \
    "Missing ${ENV_FILE}. Copy lms.env.example to lms.env before stopping the stack." \
    "缺少 ${ENV_FILE}。请先复制 lms.env.example 为 lms.env，再停止服务。" >&2
  exit 1
fi

lms_msg "Stopping Moodle..." "正在停止 Moodle..."
docker compose --env-file "${ENV_FILE}" -f "${ROOT}/moodle/docker-compose.yml" down

if [ -x "${TUTOR}" ]; then
  lms_msg "Stopping Open edX..." "正在停止 Open edX..."
  TUTOR_ROOT="${ROOT}/openedx/tutor-root" "${TUTOR}" local stop
else
  lms_msg \
    "Open edX Tutor virtual environment was not found yet." \
    "尚未找到 Open edX Tutor 虚拟环境。"
fi
