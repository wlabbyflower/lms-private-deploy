#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ROOT}/lms.env"
TUTOR_VENV="${ROOT}/.venv-tutor"
TUTOR_ROOT="${ROOT}/openedx/tutor-root"
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

if ! python3 -m venv --help >/dev/null 2>&1; then
  lms_msg \
    "python3-venv is missing. Run: ${ROOT}/scripts/00-install-docker.sh" \
    "缺少 python3-venv。请执行：${ROOT}/scripts/00-install-docker.sh" >&2
  exit 1
fi

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

OPENEDX_HTTP_BIND="${OPENEDX_HTTP_BIND:-${OPENEDX_HTTP_PORT:-80}}"
OPENEDX_LMS_URL="${OPENEDX_LMS_URL:-http://${OPENEDX_LMS_HOST}}"
OPENEDX_CMS_URL="${OPENEDX_CMS_URL:-http://${OPENEDX_CMS_HOST}}"

mkdir -p "${ROOT}/openedx" "${TUTOR_ROOT}"

if [ ! -x "${TUTOR_VENV}/bin/tutor" ]; then
  python3 -m venv "${TUTOR_VENV}"
  "${TUTOR_VENV}/bin/python" -m pip install --upgrade pip setuptools wheel
  "${TUTOR_VENV}/bin/pip" install "tutor[full]"
fi

TUTOR="${TUTOR_VENV}/bin/tutor"
export TUTOR_ROOT

PLUGIN_ROOT="$("${TUTOR}" plugins printroot 2>/dev/null || true)"
if [ -z "${PLUGIN_ROOT}" ]; then
  PLUGIN_ROOT="${HOME}/.local/share/tutor-plugins"
fi
mkdir -p "${PLUGIN_ROOT}"

cat > "${PLUGIN_ROOT}/enable_lti_provider.py" <<'PY'
"""
Tutor plugin: enable-lti-provider
Enable Open edX as an LTI 1.1 tool provider.
"""
import textwrap
from tutor import hooks

__version__ = "1.0.0"
name = "enable-lti-provider"

hooks.Filters.ENV_PATCHES.add_item(
    (
        "openedx-lms-common-settings",
        textwrap.dedent(
            """
            FEATURES['ENABLE_LTI_PROVIDER'] = True
            ENABLE_LTI_PROVIDER = True
            INSTALLED_APPS.append('lms.djangoapps.lti_provider.apps.LtiProviderConfig')
            AUTHENTICATION_BACKENDS.append('lms.djangoapps.lti_provider.users.LtiBackend')
            """
        ),
    )
)

hooks.Filters.ENV_PATCHES.add_item(
    (
        "openedx-cms-common-settings",
        textwrap.dedent(
            """
            FEATURES['ENABLE_LTI_PROVIDER'] = True
            ENABLE_LTI_PROVIDER = True
            """
        ),
    )
)
PY

"${TUTOR}" plugins enable enable_lti_provider
"${TUTOR}" config save \
  --set "LMS_HOST=${OPENEDX_LMS_HOST}" \
  --set "CMS_HOST=${OPENEDX_CMS_HOST}" \
  --set "PLATFORM_NAME=${OPENEDX_PLATFORM_NAME}" \
  --set "CONTACT_EMAIL=${OPENEDX_ADMIN_EMAIL}" \
  --set "ENABLE_HTTPS=false" \
  --set "ENABLE_WEB_PROXY=false" \
  --set "CADDY_HTTP_PORT=${OPENEDX_HTTP_BIND}"

"${TUTOR}" local launch --non-interactive

if "${TUTOR}" local do createuser --help 2>/dev/null | grep -q -- "--password"; then
  "${TUTOR}" local do createuser --staff --superuser --password "${OPENEDX_ADMIN_PASSWORD}" "${OPENEDX_ADMIN_USER}" "${OPENEDX_ADMIN_EMAIL}" || true
else
  if lms_is_zh; then
    cat <<EOF

请交互式创建 Open edX 管理员用户：
  TUTOR_ROOT=${TUTOR_ROOT} ${TUTOR} local do createuser --staff --superuser ${OPENEDX_ADMIN_USER} ${OPENEDX_ADMIN_EMAIL}
EOF
  else
    cat <<EOF

Create the Open edX admin user interactively:
  TUTOR_ROOT=${TUTOR_ROOT} ${TUTOR} local do createuser --staff --superuser ${OPENEDX_ADMIN_USER} ${OPENEDX_ADMIN_EMAIL}
EOF
  fi
fi

if lms_is_zh; then
  cat <<EOF

Open edX 正在启动。首次启动需要拉取镜像并执行迁移，耗时可能较长。

LMS：
  ${OPENEDX_LMS_URL}

Studio：
  ${OPENEDX_CMS_URL}

Tutor root：
  ${TUTOR_ROOT}

管理员密码保存在：
  ${ENV_FILE}
EOF
else
  cat <<EOF

Open edX is starting. First launch can take a long time while images are pulled and migrations run.

LMS:
  ${OPENEDX_LMS_URL}

Studio:
  ${OPENEDX_CMS_URL}

Tutor root:
  ${TUTOR_ROOT}

Admin password is stored in:
  ${ENV_FILE}
EOF
fi
