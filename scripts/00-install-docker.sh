#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${ROOT}/scripts/lib-i18n.sh"
lms_load_env_language "${ROOT}/lms.env"

if [ "${EUID}" -ne 0 ]; then
  exec sudo -E bash "$0" "$@"
fi

if ! command -v apt-get >/dev/null 2>&1; then
  lms_msg \
    "This installer expects a Debian/Ubuntu host with apt-get." \
    "此安装脚本需要带 apt-get 的 Debian/Ubuntu 主机。" >&2
  exit 1
fi

install -m 0755 -d /etc/apt/keyrings
apt-get update
apt-get install -y ca-certificates curl gnupg python3 python3-venv python3-pip

. /etc/os-release
docker_os="${ID}"
case "${docker_os}" in
  debian|ubuntu) ;;
  *) docker_os="debian" ;;
esac

if [ ! -f /etc/apt/keyrings/docker.asc ]; then
  curl -fsSL "https://download.docker.com/linux/${docker_os}/gpg" -o /etc/apt/keyrings/docker.asc
  chmod a+r /etc/apt/keyrings/docker.asc
fi

docker_apt_base_url="${DOCKER_APT_BASE_URL:-https://mirrors.ustc.edu.cn/docker-ce}"
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] ${docker_apt_base_url}/linux/${docker_os} ${VERSION_CODENAME} stable" \
  > /etc/apt/sources.list.d/docker.list

apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
systemctl enable --now docker

target_user="${SUDO_USER:-${USER}}"
if id "${target_user}" >/dev/null 2>&1; then
  usermod -aG docker "${target_user}"
fi

docker --version
docker compose version

if lms_is_zh; then
  cat <<EOF

Docker 已安装。

如果这是第一次把 ${target_user} 加入 docker 组，请执行：
  newgrp docker

然后测试：
  docker run --rm hello-world
EOF
else
  cat <<EOF

Docker is installed.

If this is the first time ${target_user} was added to the docker group, run:
  newgrp docker

Then test:
  docker run --rm hello-world
EOF
fi
