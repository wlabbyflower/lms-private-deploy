#!/usr/bin/env bash

if ! command -v lms_msg >/dev/null 2>&1; then
  lms_msg() {
    printf '%s\n' "$1"
  }
fi

ensure_docker_access() {
  if docker info >/dev/null 2>&1; then
    return 0
  fi

  if [ "${LMS_STACK_IN_DOCKER_GROUP:-0}" = "1" ]; then
    lms_msg \
      "docker daemon is not available for this user. Try opening a new shell or run: newgrp docker" \
      "当前用户无法访问 docker daemon。请打开新的 shell，或执行：newgrp docker" >&2
    exit 1
  fi

  if command -v sg >/dev/null 2>&1 && id -nG "$(id -un)" | tr ' ' '\n' | grep -qx docker; then
    export LMS_STACK_IN_DOCKER_GROUP=1
    exec sg docker -c "$(printf '%q ' "$0" "$@")"
  fi

  lms_msg \
    "docker daemon is not available for this user. Try opening a new shell or run: newgrp docker" \
    "当前用户无法访问 docker daemon。请打开新的 shell，或执行：newgrp docker" >&2
  exit 1
}
