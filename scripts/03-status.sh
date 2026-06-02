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
    "Missing ${ENV_FILE}. Copy lms.env.example to lms.env before checking the stack." \
    "缺少 ${ENV_FILE}。请先复制 lms.env.example 为 lms.env，再检查服务。" >&2
  exit 1
fi

lms_msg "Moodle status:" "Moodle 状态："
docker compose --env-file "${ENV_FILE}" -f "${ROOT}/moodle/docker-compose.yml" ps || true

if [ -x "${TUTOR}" ]; then
  lms_msg "Open edX status:" "Open edX 状态："
  TUTOR_ROOT="${ROOT}/openedx/tutor-root" "${TUTOR}" local status || true
else
  lms_msg \
    "Open edX Tutor virtual environment was not found yet." \
    "尚未找到 Open edX Tutor 虚拟环境。"
fi
