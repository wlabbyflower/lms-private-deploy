# Moodle + Open edX 私有部署 1:1 复刻手册

本文档用于把当前这台机器上已经跑通的 Moodle + Open edX 私有部署方案，完整复刻到另一台 Debian/Ubuntu 服务器。

这是一份“架构、部署方式、端口、目录、脚本、集成方式”的复刻手册，不默认迁移当前机器里的课程数据和用户数据。如果要迁移已有数据，见文末“数据迁移说明”。

## 1. 已验证方案概览

当前机器已经验证通过的版本和角色如下：

| 项目 | 方案 |
|---|---|
| 操作系统 | Debian GNU/Linux 12 bookworm |
| Docker | Docker CE，当前验证版本 `29.5.2` |
| Docker Compose | Docker Compose plugin，当前验证版本 `v5.1.4` |
| Python | Python `3.11.2` |
| Moodle | Docker Compose，`bitnamilegacy/moodle:4.5` + `bitnamilegacy/mariadb:11.4` |
| Open edX | Tutor，当前验证版本 `21.0.7` |
| Open edX 主题/插件 | `indigo`、`mfe`、自定义 `enable_lti_provider` |
| 集成方式 | Moodle 作为主入口，Open edX 作为课件/MOOC 引擎，通过 LTI 1.1 接入 |

当前机器访问地址：

```text
Moodle:
http://moodle.192.168.3.205.sslip.io:18081

Open edX LMS:
http://openedx.192.168.3.205.sslip.io

Open edX Studio:
http://studio.192.168.3.205.sslip.io
```

在另一台机器复刻时，只需要把 `192.168.3.205` 换成新机器的局域网 IP。

## 2. 为什么这样部署

Moodle 和 Open edX 都是 LMS，但强项不同，不建议把它们强行合成一个数据库或一个应用。

推荐模型：

- Moodle 做主 LMS：用户入口、课程壳、报名、通知、活动、成绩册。
- Open edX 做课程内容引擎：MOOC 课件、视频、题目、复杂学习单元。
- Moodle 通过 LTI External Tool 启动 Open edX 的内容。

这样做的好处：

- 两套系统独立升级，风险较低。
- 不共享数据库，避免数据结构冲突。
- Moodle 仍然保留课程管理和成绩册优势。
- Open edX 只负责它更擅长的课件和题目体验。
- 后续要做统一登录时，可以引入 Keycloak/OIDC/SAML，而不是把账号表硬合并。

## 3. 新机器要求

建议最低配置：

```text
CPU: 4 核以上，推荐 8 核
内存: 8 GB 以上，推荐 16 GB
磁盘: 100 GB 以上，推荐 200 GB+
系统: Debian 12 或 Ubuntu 22.04/24.04
网络: 能访问 Docker 镜像源、PyPI
端口: 新机器局域网 IP 的 80 端口可用，18081 端口可用
```

本方案默认：

- Open edX 绑定新机器局域网 IP 的 `80` 端口。
- Moodle 暴露到 `18081` 端口。
- 不启用 HTTPS，用于内网/私有测试。
- 域名使用 `sslip.io`，不需要自己配置 DNS。

`sslip.io` 的作用是把域名里的 IP 自动解析回这个 IP，例如：

```text
openedx.192.168.3.205.sslip.io -> 192.168.3.205
moodle.192.168.3.205.sslip.io -> 192.168.3.205
```

## 4. 目录结构

在新机器上使用同样的目录：

```text
/home/<USER>/lms-private-deploy
├── README.md
├── lms.env
├── lms.env.example
├── docs
│   ├── moodle-openedx-lti-tutorial.md
│   └── replicate-private-moodle-openedx.md
├── moodle
│   └── docker-compose.yml
├── openedx
│   └── tutor-root
└── scripts
    ├── 00-install-docker.sh
    ├── 01-deploy-moodle.sh
    ├── 02-deploy-openedx.sh
    ├── 03-status.sh
    ├── 04-stop.sh
    └── lib-docker-group.sh
```

注意：

- `.venv-tutor` 是自动生成的 Python 虚拟环境，不需要提前创建。
- `openedx/tutor-root` 是 Tutor 配置和数据目录，部署时自动生成。
- Moodle 数据放在 Docker volume 里。
- Open edX 数据放在 `openedx/tutor-root/data` 下。

## 5. 快速复刻方式

如果你能从当前机器复制目录，最快方式是在新机器上先复制源码目录，但不要复制运行时数据。

不要把当前机器的 `lms.env` 带到新机器，因为里面有真实密码。复制 `lms.env.example`，在新机器上生成新的 `lms.env`。

在当前机器执行：

```bash
cd /home/wlabby
tar \
  --exclude='lms-private-deploy/lms.env' \
  --exclude='lms-private-deploy/.venv-tutor' \
  --exclude='lms-private-deploy/openedx/tutor-root/data' \
  --exclude='lms-private-deploy/openedx/tutor-root/env' \
  --exclude='lms-private-deploy/openedx/tutor-root/config.yml' \
  -czf lms-private-deploy-template.tar.gz \
  lms-private-deploy
```

复制到新机器后解压：

```bash
cd /home/<USER>
tar -xzf lms-private-deploy-template.tar.gz
cd /home/<USER>/lms-private-deploy
cp lms.env.example lms.env
```

然后按第 7 节修改 `lms.env`，再从第 8 节开始部署。

## 6. 从零创建文件

如果不复制目录，也可以在新机器上手动创建。

```bash
mkdir -p /home/<USER>/lms-private-deploy/{scripts,moodle,docs,openedx}
cd /home/<USER>/lms-private-deploy
```

把后面各节的文件内容分别写入对应路径。

## 7. 环境变量文件 `lms.env`

先获取新机器的局域网 IP：

```bash
hostname -I | awk '{print $1}'
```

如果是从当前机器复制目录，先创建环境文件：

```bash
cp lms.env.example lms.env
```

假设新机器 IP 是 `192.168.3.210`，则 `lms.env` 写成：

```dotenv
# Private LMS stack defaults for this machine.
# Edit these values before first production use.

DEPLOY_HOST_IP=192.168.3.210
BASE_DOMAIN=192.168.3.210.sslip.io

MOODLE_HOST=moodle.192.168.3.210.sslip.io
MOODLE_HTTP_PORT=18081
MOODLE_ADMIN_USER=admin
MOODLE_ADMIN_PASSWORD=<CHANGE_ME>
MOODLE_ADMIN_EMAIL=admin@example.local
MOODLE_SITE_NAME="Private Moodle LMS"
MOODLE_DATABASE_NAME=bitnami_moodle
MOODLE_DATABASE_USER=bn_moodle
MOODLE_DATABASE_PASSWORD=<CHANGE_ME>
MARIADB_ROOT_PASSWORD=<CHANGE_ME>

OPENEDX_PLATFORM_NAME="Private Open edX"
OPENEDX_LMS_HOST=openedx.192.168.3.210.sslip.io
OPENEDX_CMS_HOST=studio.192.168.3.210.sslip.io
OPENEDX_HTTP_BIND=192.168.3.210:80
OPENEDX_LMS_URL=http://openedx.192.168.3.210.sslip.io
OPENEDX_CMS_URL=http://studio.192.168.3.210.sslip.io
OPENEDX_ADMIN_USER=admin
OPENEDX_ADMIN_EMAIL=admin@example.local
OPENEDX_ADMIN_PASSWORD=<CHANGE_ME>
```

生成随机密码可以用：

```bash
openssl rand -base64 24
```

必须替换：

```text
MOODLE_ADMIN_PASSWORD
MOODLE_DATABASE_PASSWORD
MARIADB_ROOT_PASSWORD
OPENEDX_ADMIN_PASSWORD
```

重要：首次启动后再改这些密码，不一定会同步到已经初始化过的数据库。生产使用前先确定好。

## 8. Docker 安装脚本

文件路径：`scripts/00-install-docker.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail

if [ "${EUID}" -ne 0 ]; then
  exec sudo -E bash "$0" "$@"
fi

if ! command -v apt-get >/dev/null 2>&1; then
  echo "This installer expects a Debian/Ubuntu host with apt-get." >&2
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

cat <<EOF

Docker is installed.

If this is the first time ${target_user} was added to the docker group, run:
  newgrp docker

Then test:
  docker run --rm hello-world
EOF
```

## 9. Docker daemon 镜像源

国内网络下 Docker Hub 可能出现 `unexpected EOF` 或下载超时。当前跑通的配置是：

文件路径：`/etc/docker/daemon.json`

```json
{
  "registry-mirrors": [
    "https://docker.m.ixdev.cn",
    "https://docker.1ms.run"
  ],
  "max-concurrent-downloads": 1,
  "max-concurrent-uploads": 1
}
```

应用配置：

```bash
sudo mkdir -p /etc/docker
sudo tee /etc/docker/daemon.json >/dev/null <<'JSON'
{
  "registry-mirrors": [
    "https://docker.m.ixdev.cn",
    "https://docker.1ms.run"
  ],
  "max-concurrent-downloads": 1,
  "max-concurrent-uploads": 1
}
JSON
sudo systemctl restart docker
```

## 10. Docker 权限辅助脚本

文件路径：`scripts/lib-docker-group.sh`

```bash
#!/usr/bin/env bash

ensure_docker_access() {
  if docker info >/dev/null 2>&1; then
    return 0
  fi

  if [ "${LMS_STACK_IN_DOCKER_GROUP:-0}" = "1" ]; then
    echo "docker daemon is not available for this user. Try opening a new shell or run: newgrp docker" >&2
    exit 1
  fi

  if command -v sg >/dev/null 2>&1 && id -nG "$(id -un)" | tr ' ' '\n' | grep -qx docker; then
    export LMS_STACK_IN_DOCKER_GROUP=1
    exec sg docker -c "$(printf '%q ' "$0" "$@")"
  fi

  echo "docker daemon is not available for this user. Try opening a new shell or run: newgrp docker" >&2
  exit 1
}
```

## 11. Moodle Compose 文件

文件路径：`moodle/docker-compose.yml`

```yaml
name: private-moodle

services:
  mariadb:
    image: docker.io/bitnamilegacy/mariadb:11.4
    restart: unless-stopped
    environment:
      MARIADB_ROOT_PASSWORD: ${MARIADB_ROOT_PASSWORD}
      MARIADB_DATABASE: ${MOODLE_DATABASE_NAME}
      MARIADB_USER: ${MOODLE_DATABASE_USER}
      MARIADB_PASSWORD: ${MOODLE_DATABASE_PASSWORD}
      MARIADB_CHARACTER_SET: utf8mb4
      MARIADB_COLLATE: utf8mb4_unicode_ci
    volumes:
      - mariadb_data:/bitnami/mariadb

  moodle:
    image: docker.io/bitnamilegacy/moodle:4.5
    restart: unless-stopped
    depends_on:
      - mariadb
    ports:
      - "${MOODLE_HTTP_PORT}:8080"
    environment:
      MOODLE_DATABASE_HOST: mariadb
      MOODLE_DATABASE_PORT_NUMBER: 3306
      MOODLE_DATABASE_NAME: ${MOODLE_DATABASE_NAME}
      MOODLE_DATABASE_USER: ${MOODLE_DATABASE_USER}
      MOODLE_DATABASE_PASSWORD: ${MOODLE_DATABASE_PASSWORD}
      MOODLE_USERNAME: ${MOODLE_ADMIN_USER}
      MOODLE_PASSWORD: ${MOODLE_ADMIN_PASSWORD}
      MOODLE_EMAIL: ${MOODLE_ADMIN_EMAIL}
      MOODLE_SITE_NAME: ${MOODLE_SITE_NAME}
      MOODLE_HOST: ${MOODLE_HOST}:${MOODLE_HTTP_PORT}
    volumes:
      - moodle_data:/bitnami/moodle
      - moodledata_data:/bitnami/moodledata

volumes:
  mariadb_data:
  moodle_data:
  moodledata_data:
```

## 12. Moodle 部署脚本

文件路径：`scripts/01-deploy-moodle.sh`

```bash
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
```

## 13. Open edX 部署脚本

文件路径：`scripts/02-deploy-openedx.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ROOT}/lms.env"
TUTOR_VENV="${ROOT}/.venv-tutor"
TUTOR_ROOT="${ROOT}/openedx/tutor-root"
source "${ROOT}/scripts/lib-docker-group.sh"

if ! command -v docker >/dev/null 2>&1; then
  echo "docker is not installed. Run: ${ROOT}/scripts/00-install-docker.sh" >&2
  exit 1
fi

ensure_docker_access "$@"

if ! python3 -m venv --help >/dev/null 2>&1; then
  echo "python3-venv is missing. Run: ${ROOT}/scripts/00-install-docker.sh" >&2
  exit 1
fi

set -a
source "${ENV_FILE}"
set +a

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
  cat <<EOF

Create the Open edX admin user interactively:
  TUTOR_ROOT=${TUTOR_ROOT} ${TUTOR} local do createuser --staff --superuser ${OPENEDX_ADMIN_USER} ${OPENEDX_ADMIN_EMAIL}
EOF
fi

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
```

## 14. 状态和停止脚本

文件路径：`scripts/03-status.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ROOT}/lms.env"
TUTOR="${ROOT}/.venv-tutor/bin/tutor"
source "${ROOT}/scripts/lib-docker-group.sh"

ensure_docker_access "$@"

docker compose --env-file "${ENV_FILE}" -f "${ROOT}/moodle/docker-compose.yml" ps || true

if [ -x "${TUTOR}" ]; then
  TUTOR_ROOT="${ROOT}/openedx/tutor-root" "${TUTOR}" local status || true
fi
```

文件路径：`scripts/04-stop.sh`

```bash
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
```

脚本授权：

```bash
chmod +x scripts/*.sh
```

## 15. 执行部署

进入目录：

```bash
cd /home/<USER>/lms-private-deploy
```

安装 Docker：

```bash
bash scripts/00-install-docker.sh
```

刷新 Docker 组权限：

```bash
newgrp docker
```

如果不想切换 shell，后续脚本也会自动尝试用 `sg docker` 执行。

测试 Docker：

```bash
docker run --rm hello-world
```

配置 Docker daemon 镜像源：

```bash
sudo mkdir -p /etc/docker
sudo tee /etc/docker/daemon.json >/dev/null <<'JSON'
{
  "registry-mirrors": [
    "https://docker.m.ixdev.cn",
    "https://docker.1ms.run"
  ],
  "max-concurrent-downloads": 1,
  "max-concurrent-uploads": 1
}
JSON
sudo systemctl restart docker
```

部署 Moodle：

```bash
bash scripts/01-deploy-moodle.sh
```

部署 Open edX：

```bash
bash scripts/02-deploy-openedx.sh
```

Open edX 首次启动会很慢，因为需要拉取大镜像、初始化数据库和运行迁移。正常情况下需要十几分钟到几十分钟，取决于机器性能和网络。

## 16. 验证部署

查看容器状态：

```bash
bash scripts/03-status.sh
```

假设新机器 IP 是 `192.168.3.210`，验证 HTTP：

```bash
curl -I http://moodle.192.168.3.210.sslip.io:18081
curl -I http://openedx.192.168.3.210.sslip.io
curl -I http://studio.192.168.3.210.sslip.io
curl -I 'http://apps.openedx.192.168.3.210.sslip.io/authn/login?next=%2F'
```

期望结果：

```text
Moodle: HTTP/1.1 200 OK
Open edX LMS: HTTP/1.1 200 OK
Open edX Studio: HTTP/1.1 302 Found，跳到 /home/
Open edX MFE login: HTTP/1.1 200 OK
```

浏览器访问：

```text
Moodle:
http://moodle.192.168.3.210.sslip.io:18081

Open edX LMS:
http://openedx.192.168.3.210.sslip.io

Open edX Studio:
http://studio.192.168.3.210.sslip.io
```

账号：

```text
Moodle admin: admin
Open edX admin: admin
密码: 查看 lms.env
```

## 17. Moodle 和 Open edX 一起使用

最终使用方式：

```text
学生/老师先进 Moodle
Moodle 课程里添加 External Tool
External Tool 打开 Open edX 的课程单元、单元页或题目组件
Open edX 通过 LTI 把成绩回传给 Moodle
```

### 17.1 在 Open edX 创建内容

打开：

```text
http://studio.<NEW_IP>.sslip.io
```

创建课程，添加内容，并发布。

Open edX 可以通过 LTI 暴露：

- subsection
- unit
- component

不建议直接暴露 section。

### 17.2 在 Open edX 注册 Moodle

打开 Open edX Admin：

```text
http://openedx.<NEW_IP>.sslip.io/admin
```

进入：

```text
LTI Provider -> LTI Consumers -> Add
```

填写：

```text
Consumer name: moodle
Consumer key: moodle-private
Consumer secret: 生成一个强密码
Instance GUID: 留空
```

身份策略：

- 简单试用：`Require user account` 和 `Use lti pii` 都不勾选。
- 需要邮箱匹配：勾选 `Use lti pii`，并让 Moodle 发送 email。
- 严格账号映射：只在两边已有匹配账号时启用 `Require user account`。

### 17.3 构造 Open edX LTI URL

URL 格式：

```text
http://openedx.<NEW_IP>.sslip.io/lti_provider/courses/{course_id}/{usage_id}
```

`course_id` 示例：

```text
course-v1:ORG+COURSE+RUN
```

`usage_id` 获取方式：

- 组件或 unit：以 staff 身份打开课程页，看 `Staff Debug Info`。
- component 的 usage ID 用 `location` 值。
- unit 的 usage ID 用 `parent` 值。
- subsection 通常可以从 courseware URL 中找到，里面会有 `type@sequential`。

### 17.4 Moodle 添加 External Tool

打开 Moodle：

```text
http://moodle.<NEW_IP>.sslip.io:18081
```

进入：

```text
Site administration
-> Plugins
-> Activity modules
-> External tool
-> Manage tools
-> Configure a tool manually
```

配置：

```text
Tool name: Open edX
Tool URL: 上一步的 LTI URL
LTI version: LTI 1.1
Consumer key: Open edX 中配置的 Consumer key
Shared secret: Open edX 中配置的 Consumer secret
Default launch container: New window
Share launcher's email: 如果 Open edX 开了 Use lti pii，则启用
Accept grades from the tool: 如果 Open edX 内容有成绩，则启用
Configuration usage: Show in activity chooser
```

然后在 Moodle 课程里添加活动，选择这个 External Tool。

## 18. 常用维护命令

状态：

```bash
cd /home/<USER>/lms-private-deploy
bash scripts/03-status.sh
```

停止：

```bash
bash scripts/04-stop.sh
```

启动 Moodle：

```bash
docker compose --env-file lms.env -f moodle/docker-compose.yml up -d
```

启动 Open edX：

```bash
TUTOR_ROOT=/home/<USER>/lms-private-deploy/openedx/tutor-root \
  /home/<USER>/lms-private-deploy/.venv-tutor/bin/tutor local start -d
```

查看 Moodle 日志：

```bash
docker compose --env-file lms.env -f moodle/docker-compose.yml logs -f moodle
```

查看 Open edX LMS 日志：

```bash
TUTOR_ROOT=/home/<USER>/lms-private-deploy/openedx/tutor-root \
  /home/<USER>/lms-private-deploy/.venv-tutor/bin/tutor local logs lms
```

## 19. 常见问题

### Docker 权限不生效

现象：

```text
permission denied while trying to connect to the docker API
```

处理：

```bash
newgrp docker
```

或重新登录 SSH。本文脚本会自动尝试 `sg docker`，但新 shell 最干净。

### Docker 镜像下载失败

现象：

```text
unexpected EOF
context canceled
TLS handshake timeout
```

处理：

```bash
sudo systemctl restart docker
bash scripts/01-deploy-moodle.sh
bash scripts/02-deploy-openedx.sh
```

如果仍失败，确认 `/etc/docker/daemon.json` 已配置镜像源，并把并发下载设置成 `1`。

### Open edX 登录跳转带错端口

本方案让 Open edX 直接占用新机器局域网 IP 的 `80` 端口，避免 Tutor 生成的 MFE 登录链接缺少端口导致跳错。

关键配置：

```dotenv
OPENEDX_HTTP_BIND=<NEW_IP>:80
OPENEDX_LMS_HOST=openedx.<NEW_IP>.sslip.io
OPENEDX_CMS_HOST=studio.<NEW_IP>.sslip.io
```

Tutor 配置里对应：

```yaml
CADDY_HTTP_PORT: <NEW_IP>:80
ENABLE_HTTPS: false
ENABLE_WEB_PROXY: false
```

### 80 端口被占用

检查：

```bash
sudo ss -ltnp | grep ':80'
```

如果新机器已有 Nginx/Apache/Caddy 占用 80，要么停掉已有服务，要么改成反向代理方案。内网快速复刻时，建议让 Open edX 独占 `<NEW_IP>:80`。

### Moodle 或 Open edX 第一次打开很慢

首次启动会初始化数据库、编译/加载服务，等几分钟后再访问。用下面命令看状态：

```bash
bash scripts/03-status.sh
```

## 20. 数据迁移说明

如果只是复刻部署方案，不需要迁移数据。

如果要把当前机器的已有课程、用户和配置也迁移到新机器，需要额外备份：

Moodle：

- Docker volumes：`private-moodle_mariadb_data`、`private-moodle_moodle_data`、`private-moodle_moodledata_data`
- 或用 Moodle 后台做课程备份/恢复

Open edX：

- `openedx/tutor-root/data`
- `openedx/tutor-root/config.yml`
- Tutor 生成的环境文件

数据迁移比纯部署复杂，建议先在新机器按本文完成空系统部署，再单独做备份恢复演练。

## 21. 生产化建议

当前方案是内网 HTTP 私有部署。生产环境建议：

- 使用真实域名，不再使用 `sslip.io`。
- 启用 HTTPS。
- 使用统一身份认证，例如 Keycloak + OIDC/SAML。
- 配置定期备份。
- 配置 SMTP，让 Moodle/Open edX 可以发邮件。
- 把 Moodle 和 Open edX 都放到统一反向代理后面。

推荐域名结构：

```text
moodle.example.com
openedx.example.com
studio.example.com
apps.openedx.example.com
```

## 22. 官方参考

- Tutor local deployment: https://docs.tutor.edly.io/local.html
- Tutor behind existing web proxy: https://docs.tutor.edly.io/sysadmin/proxy.html
- Open edX as LTI provider: https://docs.openedx.org/en/latest/educators/concepts/advanced_features/using_openedx_as_LTI_provider.html
- Moodle External Tool/LTI: https://docs.moodle.org/501/en/mod/lti/index
- Bitnami Moodle container: https://hub.docker.com/r/bitnami/moodle
