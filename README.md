# LMS Private Deploy

English is the default language for this project. Chinese text is provided directly after each major instruction.

本项目默认使用英文显示。中文说明会紧跟在主要英文说明之后。

Moodle + Open edX single-server deployment template.

Moodle + Open edX 单服务器部署模板。

Moodle is used as the main learner-facing LMS: entry point, enrollment, course shell, activities, notifications, and gradebook. Open edX is used as the courseware engine: MOOC-style content, videos, problems, and reusable learning units. Moodle launches selected Open edX content through LTI 1.1.

Moodle 作为面向学习者的主 LMS，负责入口、报名、课程壳、活动、通知和成绩册。Open edX 作为课件引擎，负责 MOOC 风格内容、视频、题目和可复用学习单元。Moodle 通过 LTI 1.1 打开指定的 Open edX 内容。

## Language / 语言

Scripts display English by default. Set `LMS_LANG=zh` in `lms.env` or in the shell to show Chinese messages.

脚本默认显示英文。如需中文提示，请在 `lms.env` 或当前 shell 中设置 `LMS_LANG=zh`。

```bash
LMS_LANG=zh bash scripts/03-status.sh
```

## What Is Included / 仓库内容

```text
.
├── docs
│   ├── moodle-openedx-lti-tutorial.md
│   └── replicate-private-moodle-openedx.md
├── moodle
│   └── docker-compose.yml
├── openedx
│   └── tutor-root/              # Generated Tutor config/data on a deployed host
├── scripts
│   ├── 00-install-docker.sh
│   ├── 01-deploy-moodle.sh
│   ├── 02-deploy-openedx.sh
│   ├── 03-status.sh
│   ├── 04-stop.sh
│   ├── lib-docker-group.sh
│   └── lib-i18n.sh
├── lms.env.example
└── README.md
```

Runtime and secret files are intentionally local to each machine. Do not publish `lms.env`, `.venv-tutor/`, `openedx/tutor-root/data/`, generated Tutor secrets, logs, certificates, or database files.

运行时文件和密钥文件应保留在各自机器本地。不要发布 `lms.env`、`.venv-tutor/`、`openedx/tutor-root/data/`、Tutor 生成的密钥、日志、证书或数据库文件。

## Verified Stack / 已验证环境

The current deployment has been verified with:

当前部署已用以下环境验证：

- Debian GNU/Linux 12
- Docker CE and Docker Compose plugin
- Moodle 4.5 LTS with MariaDB 11.4 through Docker Compose
- Open edX through Tutor 21.0.7
- Tutor plugins: `indigo`, `mfe`, and a local `enable_lti_provider` plugin
- LTI 1.1 from Moodle External Tool to Open edX LTI provider

## Quick Start / 快速开始

Prepare the environment file.

准备环境变量文件。

```bash
cp lms.env.example lms.env
```

Replace every `NEW_IP` value in `lms.env` with the server IP, keep `LMS_LANG=en` for English, or set `LMS_LANG=zh` for Chinese. Then generate fresh passwords for:

把 `lms.env` 中所有 `NEW_IP` 替换为服务器 IP。默认保留 `LMS_LANG=en` 显示英文，如需中文改为 `LMS_LANG=zh`。然后为以下变量生成新密码：

```text
MOODLE_ADMIN_PASSWORD
MOODLE_DATABASE_PASSWORD
MARIADB_ROOT_PASSWORD
OPENEDX_ADMIN_PASSWORD
```

Install Docker and basic prerequisites.

安装 Docker 和基础依赖。

```bash
bash scripts/00-install-docker.sh
newgrp docker
docker run --rm hello-world
```

Deploy Moodle.

部署 Moodle。

```bash
bash scripts/01-deploy-moodle.sh
```

Deploy Open edX.

部署 Open edX。

```bash
bash scripts/02-deploy-openedx.sh
```

Check status or stop the stack.

检查状态或停止服务。

```bash
bash scripts/03-status.sh
bash scripts/04-stop.sh
```

## Default Access Pattern / 默认访问方式

The template uses `sslip.io`, so a separate DNS setup is not required. Replace `NEW_IP` with the server IP:

本模板使用 `sslip.io`，不需要单独配置 DNS。请把 `NEW_IP` 替换为服务器 IP：

```text
Moodle:
http://moodle.NEW_IP.sslip.io:18081

Open edX LMS:
http://openedx.NEW_IP.sslip.io

Open edX Studio:
http://studio.NEW_IP.sslip.io
```

Open edX uses `OPENEDX_HTTP_BIND`, normally `NEW_IP:80`. Moodle is exposed on port `18081`.

Open edX 使用 `OPENEDX_HTTP_BIND`，通常为 `NEW_IP:80`。Moodle 暴露在 `18081` 端口。

## LTI Integration / LTI 集成

Use Moodle as the learner-facing LMS and add Open edX content as Moodle External Tool activities.

使用 Moodle 作为学习者入口，并把 Open edX 内容添加为 Moodle External Tool 活动。

The bilingual LTI setup guide is here:

双语 LTI 配置指南：

```text
docs/moodle-openedx-lti-tutorial.md
```

High-level flow:

整体流程：

1. Create and publish content in Open edX Studio.
2. Add Moodle as an LTI consumer in the Open edX LMS admin.
3. Build the Open edX LTI launch URL for a subsection, unit, or component.
4. Configure Moodle External Tool with the Open edX consumer key and secret.
5. Add the tool inside a Moodle course and test as a learner.

对应中文：

1. 在 Open edX Studio 创建并发布内容。
2. 在 Open edX LMS 管理后台把 Moodle 添加为 LTI consumer。
3. 为 subsection、unit 或 component 构造 Open edX LTI 启动 URL。
4. 在 Moodle External Tool 中配置 Open edX consumer key 和 secret。
5. 在 Moodle 课程中添加该工具，并以学习者身份测试。

## Reproducing The Deployment / 复刻部署

For a full redeploy walkthrough, including host requirements, directory layout, environment variables, Docker mirror notes, deployment commands, LTI setup, maintenance commands, and migration notes, read:

完整复刻指南包含主机要求、目录结构、环境变量、Docker 镜像源、部署命令、LTI 配置、维护命令和迁移说明：

```text
docs/replicate-private-moodle-openedx.md
```

That guide explains how to replicate the deployment to another Debian/Ubuntu server without carrying over machine-specific secrets or runtime data.

该指南说明如何把部署方案复刻到另一台 Debian/Ubuntu 服务器，同时避免带入本机密钥或运行时数据。

## Production Notes / 生产环境说明

This setup defaults to HTTP for testing. For production, put Moodle and Open edX behind HTTPS with real domains, for example:

本方案默认使用 HTTP 便于测试。生产环境建议把 Moodle 和 Open edX 放到 HTTPS 和真实域名之后，例如：

```text
moodle.example.com
openedx.example.com
studio.example.com
```

Keep Moodle and Open edX as separate applications with separate databases. If shared login is required, use Keycloak or another OIDC/SAML identity provider instead of merging user tables.

保持 Moodle 和 Open edX 作为独立应用，并使用独立数据库。如果需要统一登录，建议使用 Keycloak 或其他 OIDC/SAML 身份提供方，不要合并用户表。

Recommended production hardening:

生产环境建议：

- Use HTTPS and a reverse proxy.
- Rotate all generated passwords and Tutor secrets before real use.
- Back up Moodle Docker volumes and Open edX Tutor data separately.
- Keep `lms.env` and Tutor-generated secrets outside Git.
- Test LTI launch and grade passback after every domain, HTTPS, or identity-provider change.

对应中文：

- 使用 HTTPS 和反向代理。
- 正式使用前轮换所有生成的密码和 Tutor 密钥。
- 分别备份 Moodle Docker volumes 和 Open edX Tutor 数据。
- 不要把 `lms.env` 和 Tutor 生成的密钥提交到 Git。
- 每次修改域名、HTTPS 或身份认证后，都要测试 LTI 启动和成绩回传。

## References / 参考资料

- Tutor local deployment: https://docs.tutor.edly.io/local.html
- Tutor behind an existing web proxy: https://docs.tutor.edly.io/sysadmin/proxy.html
- Open edX LTI provider documentation: https://docs.openedx.org/en/latest/educators/concepts/advanced_features/using_openedx_as_LTI_provider.html
- Moodle External Tool/LTI documentation: https://docs.moodle.org/501/en/mod/lti/index
