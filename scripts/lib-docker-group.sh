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
