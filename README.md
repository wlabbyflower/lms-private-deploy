# LMS Private Deploy

Moodle + Open edX single-server private deployment template.

This project runs Moodle as the main LMS and Open edX as the courseware engine. Moodle provides the learner entry point, enrollment, course shell, activities, notifications, and gradebook. Open edX provides MOOC-style content, videos, problems, and reusable learning units. Moodle launches selected Open edX content through LTI 1.1.

## What Is Included

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
│   └── lib-docker-group.sh
├── lms.env.example
└── README.md
```

Runtime and secret files are intentionally local to each machine. Do not publish `lms.env`, `.venv-tutor/`, `openedx/tutor-root/data/`, generated Tutor secrets, logs, certificates, or database files.

## Verified Stack

The current deployment has been verified with:

- Debian GNU/Linux 12
- Docker CE and Docker Compose plugin
- Moodle 4.5 LTS with MariaDB 11.4 through Docker Compose
- Open edX through Tutor 21.0.7
- Tutor plugins: `indigo`, `mfe`, and a local `enable_lti_provider` plugin
- LTI 1.1 from Moodle External Tool to Open edX LTI provider

## Quick Start

Prepare the environment file:

```bash
cp lms.env.example lms.env
```

Replace every `NEW_IP` value in `lms.env` with the server LAN IP, then generate fresh passwords for:

```text
MOODLE_ADMIN_PASSWORD
MOODLE_DATABASE_PASSWORD
MARIADB_ROOT_PASSWORD
OPENEDX_ADMIN_PASSWORD
```

Install Docker and basic prerequisites:

```bash
bash scripts/00-install-docker.sh
newgrp docker
docker run --rm hello-world
```

Deploy Moodle:

```bash
bash scripts/01-deploy-moodle.sh
```

Deploy Open edX:

```bash
bash scripts/02-deploy-openedx.sh
```

Check status or stop the stack:

```bash
bash scripts/03-status.sh
bash scripts/04-stop.sh
```

## Default Access Pattern

The template uses `sslip.io` so local/private DNS setup is not required. For a server IP such as `192.168.3.205`, the default URLs are:

```text
Moodle:
http://moodle.192.168.3.205.sslip.io:18081

Open edX LMS:
http://openedx.192.168.3.205.sslip.io

Open edX Studio:
http://studio.192.168.3.205.sslip.io
```

Open edX is bound to the server LAN IP on port `80`. Moodle is exposed on port `18081`.

## LTI Integration

Use Moodle as the learner-facing LMS and add Open edX content as Moodle External Tool activities.

The full LTI setup guide is here:

```text
docs/moodle-openedx-lti-tutorial.md
```

High-level flow:

1. Create and publish content in Open edX Studio.
2. Add Moodle as an LTI consumer in the Open edX LMS admin.
3. Build the Open edX LTI launch URL for a subsection, unit, or component.
4. Configure Moodle External Tool with the Open edX consumer key and secret.
5. Add the tool inside a Moodle course and test as a learner.

## Reproducing The Deployment

For a complete copy/redeploy walkthrough, including host requirements, directory layout, environment variables, Docker mirror notes, script contents, and data migration notes, read:

```text
docs/replicate-private-moodle-openedx.md
```

That guide explains how to replicate the deployment to another Debian/Ubuntu server without carrying over machine-specific secrets or runtime data.

## Production Notes

This setup defaults to HTTP for local/private testing. For production, put Moodle and Open edX behind HTTPS with real domains, for example:

```text
moodle.example.com
openedx.example.com
studio.example.com
```

Keep Moodle and Open edX as separate applications with separate databases. If shared login is required, use Keycloak or another OIDC/SAML identity provider instead of merging user tables.

Recommended production hardening:

- Use HTTPS and a reverse proxy.
- Rotate all generated passwords and Tutor secrets before real use.
- Back up Moodle Docker volumes and Open edX Tutor data separately.
- Keep `lms.env` and Tutor-generated secrets outside Git.
- Test LTI launch and grade passback after every domain, HTTPS, or identity-provider change.

## References

- Tutor local deployment: https://docs.tutor.edly.io/local.html
- Tutor behind an existing web proxy: https://docs.tutor.edly.io/sysadmin/proxy.html
- Open edX LTI provider documentation: https://docs.openedx.org/en/latest/educators/concepts/advanced_features/using_openedx_as_LTI_provider.html
- Moodle External Tool/LTI documentation: https://docs.moodle.org/501/en/mod/lti/index
