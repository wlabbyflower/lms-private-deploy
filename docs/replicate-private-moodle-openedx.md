# Moodle + Open edX Redeploy Guide

# Moodle + Open edX 复刻部署指南

English is the default language. Chinese follows each major section.

本指南默认英文在前，中文说明紧随每个主要章节。

This guide explains how to reproduce the Moodle + Open edX deployment on another Debian/Ubuntu server. It covers architecture, requirements, directories, environment variables, deployment commands, LTI setup, maintenance, and migration notes. It does not migrate existing course data or user data by default.

本文说明如何把 Moodle + Open edX 部署方案复刻到另一台 Debian/Ubuntu 服务器，内容包括架构、机器要求、目录、环境变量、部署命令、LTI 配置、维护和迁移说明。默认不迁移已有课程数据或用户数据。

## 1. Verified Design / 已验证方案

The verified roles and versions are:

已验证的角色和版本如下：

| Item | Design |
|---|---|
| Operating system | Debian GNU/Linux 12 bookworm |
| Docker | Docker CE |
| Docker Compose | Docker Compose plugin |
| Python | Python 3.11 |
| Moodle | Docker Compose, `bitnamilegacy/moodle:4.5` + `bitnamilegacy/mariadb:11.4` |
| Open edX | Tutor 21.0.7 |
| Open edX theme/plugins | `indigo`, `mfe`, local `enable_lti_provider` plugin |
| Integration | Moodle is the main LMS. Open edX is the courseware engine. Moodle launches Open edX content through LTI 1.1. |

Default URLs use the server IP through `sslip.io`. Replace `NEW_IP` with the actual server IP:

默认 URL 通过 `sslip.io` 使用服务器 IP。请把 `NEW_IP` 替换为实际服务器 IP：

```text
Moodle:
http://moodle.NEW_IP.sslip.io:18081

Open edX LMS:
http://openedx.NEW_IP.sslip.io

Open edX Studio:
http://studio.NEW_IP.sslip.io
```

## 2. Why Moodle and Open edX Stay Separate / 为什么保持两套系统独立

Moodle and Open edX are both learning platforms, but they are optimized for different work:

Moodle 和 Open edX 都是学习平台，但擅长的方向不同：

- Moodle handles learner entry, course shells, enrollment, activities, notifications, and gradebook.
- Open edX handles MOOC-style courseware, videos, problems, and reusable learning units.
- Moodle launches Open edX content through LTI External Tool activities.
- Moodle 负责学习者入口、课程壳、报名、活动、通知和成绩册。
- Open edX 负责 MOOC 风格课件、视频、题目和可复用学习单元。
- Moodle 通过 LTI External Tool 启动 Open edX 内容。

Do not merge the two databases or user tables. If shared login is required later, use Keycloak or another OIDC/SAML identity provider.

不要合并两套系统的数据库或用户表。如果后续需要统一登录，使用 Keycloak 或其他 OIDC/SAML 身份提供方。

## 3. Server Requirements / 服务器要求

Recommended minimum:

建议最低配置：

```text
CPU: 4 cores minimum, 8 cores recommended
Memory: 8 GB minimum, 16 GB recommended
Disk: 100 GB minimum, 200 GB+ recommended
System: Debian 12 or Ubuntu 22.04/24.04
Network: access to Docker image registries and PyPI
Ports: server IP port 80 available, port 18081 available
```

The deployment defaults are:

默认部署方式：

- Open edX binds to `NEW_IP:80`.
- Moodle listens on port `18081`.
- HTTPS is disabled for the initial test deployment.
- `sslip.io` is used, so custom DNS is not required.
- Open edX 绑定 `NEW_IP:80`。
- Moodle 使用 `18081` 端口。
- 初始测试部署不启用 HTTPS。
- 使用 `sslip.io`，不需要自定义 DNS。

`sslip.io` resolves hostnames containing the IP back to that IP:

`sslip.io` 会把域名中的 IP 解析回该 IP：

```text
openedx.NEW_IP.sslip.io -> NEW_IP
moodle.NEW_IP.sslip.io -> NEW_IP
```

## 4. Directory Layout / 目录结构

Use the same layout on the target server:

在目标服务器上使用相同目录结构：

```text
/home/<USER>/lms-private-deploy
├── .gitignore
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
    ├── lib-docker-group.sh
    └── lib-i18n.sh
```

Generated runtime paths:

运行时自动生成的路径：

- `.venv-tutor/`: Tutor Python virtual environment.
- `openedx/tutor-root/`: Tutor configuration and data.
- Moodle data: Docker volumes.
- `.venv-tutor/`：Tutor Python 虚拟环境。
- `openedx/tutor-root/`：Tutor 配置和数据。
- Moodle 数据：Docker volumes。

## 5. Copying the Template / 复制模板

Fastest method: copy the source tree, but do not copy machine-specific runtime data or secrets.

最快方式是复制源码目录，但不要复制绑定机器的运行时数据和密钥。

From the source machine:

在源机器执行：

```bash
cd /home/<USER>
tar \
  --exclude='lms-private-deploy/lms.env' \
  --exclude='lms-private-deploy/.venv-tutor' \
  --exclude='lms-private-deploy/openedx/tutor-root' \
  -czf lms-private-deploy-template.tar.gz \
  lms-private-deploy
```

On the target server:

在目标服务器执行：

```bash
cd /home/<USER>
tar -xzf lms-private-deploy-template.tar.gz
cd /home/<USER>/lms-private-deploy
cp lms.env.example lms.env
```

Then edit `lms.env`, install Docker, and deploy.

然后修改 `lms.env`，安装 Docker 并部署。

## 6. Environment File / 环境变量文件

Get the server IP:

获取服务器 IP：

```bash
hostname -I | awk '{print $1}'
```

Copy the example file:

复制示例文件：

```bash
cp lms.env.example lms.env
```

Example `lms.env` values. Replace every `NEW_IP` with the server IP and replace all `<CHANGE_ME>` values:

下面是 `lms.env` 示例。请把所有 `NEW_IP` 替换为服务器 IP，并替换所有 `<CHANGE_ME>`：

```dotenv
LMS_LANG=en

DEPLOY_HOST_IP=NEW_IP
BASE_DOMAIN=NEW_IP.sslip.io

MOODLE_HOST=moodle.NEW_IP.sslip.io
MOODLE_HTTP_PORT=18081
MOODLE_ADMIN_USER=admin
MOODLE_ADMIN_PASSWORD=<CHANGE_ME>
MOODLE_ADMIN_EMAIL=admin@example.local
MOODLE_SITE_NAME="Moodle LMS"
MOODLE_DATABASE_NAME=bitnami_moodle
MOODLE_DATABASE_USER=bn_moodle
MOODLE_DATABASE_PASSWORD=<CHANGE_ME>
MARIADB_ROOT_PASSWORD=<CHANGE_ME>

OPENEDX_PLATFORM_NAME="Open edX"
OPENEDX_LMS_HOST=openedx.NEW_IP.sslip.io
OPENEDX_CMS_HOST=studio.NEW_IP.sslip.io
OPENEDX_HTTP_BIND=NEW_IP:80
OPENEDX_LMS_URL=http://openedx.NEW_IP.sslip.io
OPENEDX_CMS_URL=http://studio.NEW_IP.sslip.io
OPENEDX_ADMIN_USER=admin
OPENEDX_ADMIN_EMAIL=admin@example.local
OPENEDX_ADMIN_PASSWORD=<CHANGE_ME>
```

`LMS_LANG=en` keeps script messages in English. Use `LMS_LANG=zh` for Chinese messages.

`LMS_LANG=en` 表示脚本提示使用英文。改为 `LMS_LANG=zh` 可显示中文。

Generate random passwords:

生成随机密码：

```bash
openssl rand -base64 24
```

Required password variables:

必须替换的密码变量：

```text
MOODLE_ADMIN_PASSWORD
MOODLE_DATABASE_PASSWORD
MARIADB_ROOT_PASSWORD
OPENEDX_ADMIN_PASSWORD
```

Important: changing these values after first boot may not update databases that have already been initialized. Finalize passwords before production use.

重要：首次启动后再修改这些值，不一定会同步到已初始化的数据库。正式使用前先确定好密码。

## 7. Install Docker / 安装 Docker

Run the included installer:

执行仓库自带安装脚本：

```bash
bash scripts/00-install-docker.sh
```

Refresh Docker group membership:

刷新 Docker 组权限：

```bash
newgrp docker
```

Test Docker:

测试 Docker：

```bash
docker run --rm hello-world
```

If Docker image downloads are unstable, configure registry mirrors:

如果 Docker 镜像下载不稳定，可以配置镜像源：

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

The installer uses `DOCKER_APT_BASE_URL` when provided. Example:

安装脚本支持通过 `DOCKER_APT_BASE_URL` 指定 Docker apt 源，例如：

```bash
DOCKER_APT_BASE_URL=https://download.docker.com bash scripts/00-install-docker.sh
```

## 8. Deploy Moodle / 部署 Moodle

Run:

执行：

```bash
bash scripts/01-deploy-moodle.sh
```

Expected URL:

预期访问地址：

```text
http://moodle.NEW_IP.sslip.io:18081
```

## 9. Deploy Open edX / 部署 Open edX

Run:

执行：

```bash
bash scripts/02-deploy-openedx.sh
```

First launch can take a long time because Tutor pulls large images, initializes databases, and runs migrations.

首次启动可能耗时较长，因为 Tutor 需要拉取大镜像、初始化数据库并执行迁移。

Expected URLs:

预期访问地址：

```text
http://openedx.NEW_IP.sslip.io
http://studio.NEW_IP.sslip.io
```

## 10. Verify / 验证

Check status:

检查状态：

```bash
bash scripts/03-status.sh
```

Verify HTTP responses:

验证 HTTP 响应：

```bash
curl -I http://moodle.NEW_IP.sslip.io:18081
curl -I http://openedx.NEW_IP.sslip.io
curl -I http://studio.NEW_IP.sslip.io
curl -I 'http://apps.openedx.NEW_IP.sslip.io/authn/login?next=%2F'
```

Expected results:

预期结果：

```text
Moodle: HTTP/1.1 200 OK
Open edX LMS: HTTP/1.1 200 OK
Open edX Studio: HTTP/1.1 302 Found, redirecting to /home/
Open edX MFE login: HTTP/1.1 200 OK
```

Browser URLs:

浏览器访问地址：

```text
Moodle:
http://moodle.NEW_IP.sslip.io:18081

Open edX LMS:
http://openedx.NEW_IP.sslip.io

Open edX Studio:
http://studio.NEW_IP.sslip.io
```

Accounts:

账号：

```text
Moodle admin: admin
Open edX admin: admin
Password: check lms.env
```

## 11. LTI Setup / LTI 配置

The usage model:

使用模型：

```text
Learners/teachers enter Moodle first.
Moodle courses contain External Tool activities.
External Tool launches an Open edX subsection, unit, or component.
Open edX returns grades to Moodle through LTI.
```

中文：

```text
学生/老师先进入 Moodle。
Moodle 课程中添加 External Tool 活动。
External Tool 打开 Open edX 的 subsection、unit 或 component。
Open edX 通过 LTI 把成绩回传给 Moodle。
```

Detailed steps are documented in:

详细步骤见：

```text
docs/moodle-openedx-lti-tutorial.md
```

Short version:

简要流程：

1. Create and publish content in Open edX Studio: `http://studio.NEW_IP.sslip.io`.
2. Register Moodle in Open edX admin: `http://openedx.NEW_IP.sslip.io/admin`.
3. Build the LTI URL: `http://openedx.NEW_IP.sslip.io/lti_provider/courses/{course_id}/{usage_id}`.
4. Add the URL as a Moodle External Tool: `http://moodle.NEW_IP.sslip.io:18081`.
5. Test as a learner.

对应中文：

1. 在 Open edX Studio 创建并发布内容：`http://studio.NEW_IP.sslip.io`。
2. 在 Open edX 管理后台注册 Moodle：`http://openedx.NEW_IP.sslip.io/admin`。
3. 构造 LTI URL：`http://openedx.NEW_IP.sslip.io/lti_provider/courses/{course_id}/{usage_id}`。
4. 在 Moodle 添加 External Tool：`http://moodle.NEW_IP.sslip.io:18081`。
5. 以学习者身份测试。

## 12. Maintenance Commands / 常用维护命令

Status:

查看状态：

```bash
cd /home/<USER>/lms-private-deploy
bash scripts/03-status.sh
```

Stop:

停止：

```bash
bash scripts/04-stop.sh
```

Start Moodle:

启动 Moodle：

```bash
docker compose --env-file lms.env -f moodle/docker-compose.yml up -d
```

Start Open edX:

启动 Open edX：

```bash
TUTOR_ROOT=/home/<USER>/lms-private-deploy/openedx/tutor-root \
  /home/<USER>/lms-private-deploy/.venv-tutor/bin/tutor local start -d
```

Moodle logs:

查看 Moodle 日志：

```bash
docker compose --env-file lms.env -f moodle/docker-compose.yml logs -f moodle
```

Open edX LMS logs:

查看 Open edX LMS 日志：

```bash
TUTOR_ROOT=/home/<USER>/lms-private-deploy/openedx/tutor-root \
  /home/<USER>/lms-private-deploy/.venv-tutor/bin/tutor local logs lms
```

## 13. Troubleshooting / 常见问题

### Docker group permission does not apply / Docker 权限不生效

Symptom:

现象：

```text
permission denied while trying to connect to the docker API
```

Fix:

处理：

```bash
newgrp docker
```

Or log out and log in again through SSH. The scripts also try `sg docker` automatically when available.

或者重新登录 SSH。脚本在可用时也会自动尝试 `sg docker`。

### Docker image downloads fail / Docker 镜像下载失败

Symptom:

现象：

```text
unexpected EOF
context canceled
TLS handshake timeout
```

Fix:

处理：

```bash
sudo systemctl restart docker
bash scripts/01-deploy-moodle.sh
bash scripts/02-deploy-openedx.sh
```

If the issue persists, configure `/etc/docker/daemon.json` mirrors and set concurrent downloads to `1`.

如果仍失败，确认 `/etc/docker/daemon.json` 已配置镜像源，并把并发下载设置为 `1`。

### Open edX login redirects with the wrong port / Open edX 登录跳转端口错误

This template lets Open edX use `NEW_IP:80` directly, which avoids MFE login links missing the expected port.

本模板让 Open edX 直接使用 `NEW_IP:80`，避免 Tutor 生成的 MFE 登录链接缺少预期端口。

Key environment values:

关键环境变量：

```dotenv
OPENEDX_HTTP_BIND=NEW_IP:80
OPENEDX_LMS_HOST=openedx.NEW_IP.sslip.io
OPENEDX_CMS_HOST=studio.NEW_IP.sslip.io
```

Tutor configuration maps this to:

Tutor 配置中对应：

```yaml
CADDY_HTTP_PORT: NEW_IP:80
ENABLE_HTTPS: false
ENABLE_WEB_PROXY: false
```

### Port 80 is already in use / 80 端口被占用

Check:

检查：

```bash
sudo ss -ltnp | grep ':80'
```

If another Nginx/Apache/Caddy process is using port 80, stop that service or switch to a reverse-proxy design.

如果已有 Nginx/Apache/Caddy 占用 80 端口，请停止该服务，或改用反向代理方案。

### First page load is slow / 第一次打开很慢

First launch initializes databases and services. Wait a few minutes and check:

首次启动会初始化数据库和服务。等待几分钟后检查：

```bash
bash scripts/03-status.sh
```

## 14. Data Migration / 数据迁移

If you only reproduce the deployment, no data migration is required.

如果只是复刻部署方案，不需要迁移数据。

To migrate existing courses, users, and configuration, back up these separately:

如果需要迁移已有课程、用户和配置，需要分别备份：

Moodle:

- Docker volumes: `private-moodle_mariadb_data`, `private-moodle_moodle_data`, `private-moodle_moodledata_data`
- Or use Moodle course backup/restore from the Moodle UI

Moodle：

- Docker volumes：`private-moodle_mariadb_data`、`private-moodle_moodle_data`、`private-moodle_moodledata_data`
- 或使用 Moodle 后台的课程备份/恢复功能

Open edX:

- `openedx/tutor-root/data`
- `openedx/tutor-root/config.yml`
- Tutor-generated environment files

Open edX：

- `openedx/tutor-root/data`
- `openedx/tutor-root/config.yml`
- Tutor 生成的环境文件

Data migration is more complex than reproducing the deployment. First complete an empty deployment on the target server, then do a backup/restore rehearsal.

数据迁移比纯部署更复杂。建议先在目标服务器完成空系统部署，再单独做备份恢复演练。

## 15. Production Recommendations / 生产化建议

For production:

生产环境建议：

- Use real domains instead of `sslip.io`.
- Enable HTTPS.
- Use centralized identity, such as Keycloak with OIDC/SAML.
- Configure scheduled backups.
- Configure SMTP so Moodle and Open edX can send email.
- Put Moodle and Open edX behind a managed reverse proxy.
- 使用真实域名，不再使用 `sslip.io`。
- 启用 HTTPS。
- 使用统一身份认证，例如 Keycloak + OIDC/SAML。
- 配置定期备份。
- 配置 SMTP，让 Moodle/Open edX 可以发送邮件。
- 把 Moodle 和 Open edX 放到统一反向代理后面。

Recommended domain structure:

推荐域名结构：

```text
moodle.example.com
openedx.example.com
studio.example.com
apps.openedx.example.com
```

## 16. Official References / 官方参考

- Tutor local deployment: https://docs.tutor.edly.io/local.html
- Tutor behind existing web proxy: https://docs.tutor.edly.io/sysadmin/proxy.html
- Open edX as LTI provider: https://docs.openedx.org/en/latest/educators/concepts/advanced_features/using_openedx_as_LTI_provider.html
- Moodle External Tool/LTI: https://docs.moodle.org/501/en/mod/lti/index
- Bitnami Moodle container: https://hub.docker.com/r/bitnami/moodle
