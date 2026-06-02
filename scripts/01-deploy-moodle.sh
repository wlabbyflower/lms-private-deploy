#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ROOT}/lms.env"
COMPOSE_FILE="${ROOT}/moodle/docker-compose.yml"
LMS_LANG_FROM_SHELL="${LMS_LANG-}"
source "${ROOT}/scripts/lib-i18n.sh"
lms_load_env_language "${ENV_FILE}"
source "${ROOT}/scripts/lib-docker-group.sh"

if ! command -v docker >/dev/null 2>&1; then
  lms_msg \
    "docker is not installed. Run: ${ROOT}/scripts/00-install-docker.sh" \
    "尚未安装 docker。请执行：${ROOT}/scripts/00-install-docker.sh" >&2
  exit 1
fi

ensure_docker_access "$@"

if [ ! -f "${ENV_FILE}" ]; then
  lms_msg \
    "Missing ${ENV_FILE}. Copy lms.env.example to lms.env, replace NEW_IP, and set fresh passwords." \
    "缺少 ${ENV_FILE}。请先复制 lms.env.example 为 lms.env，替换 NEW_IP，并设置新密码。" >&2
  exit 1
fi

set -a
source "${ENV_FILE}"
set +a
if [ -n "${LMS_LANG_FROM_SHELL}" ]; then
  export LMS_LANG="${LMS_LANG_FROM_SHELL}"
fi

docker compose --env-file "${ENV_FILE}" -f "${COMPOSE_FILE}" pull
docker compose --env-file "${ENV_FILE}" -f "${COMPOSE_FILE}" up -d

if lms_is_zh; then
  cat <<EOF

Moodle 正在启动。首次启动可能需要几分钟。

URL：
  http://${MOODLE_HOST}:${MOODLE_HTTP_PORT}

管理员：
  ${MOODLE_ADMIN_USER}

密码保存在：
  ${ENV_FILE}

检查状态：
  docker compose --env-file "${ENV_FILE}" -f "${COMPOSE_FILE}" ps
EOF
else
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
fi
