#!/usr/bin/env bash

lms_language() {
  case "${LMS_LANG:-en}" in
    zh|zh_CN|zh-CN|cn|cn_*|Chinese|chinese) printf 'zh' ;;
    *) printf 'en' ;;
  esac
}

lms_is_zh() {
  [ "$(lms_language)" = "zh" ]
}

lms_load_env_language() {
  local env_file="${1:-}"
  local env_lang

  [ -n "${env_file}" ] || return 0
  [ -f "${env_file}" ] || return 0
  [ -z "${LMS_LANG+x}" ] || return 0

  env_lang="$(
    awk -F= '
      /^[[:space:]]*LMS_LANG[[:space:]]*=/ {
        value=$2
        gsub(/^[[:space:]"'\''"]+|[[:space:]"'\''"]+$/, "", value)
        print value
        exit
      }
    ' "${env_file}"
  )"

  if [ -n "${env_lang}" ]; then
    export LMS_LANG="${env_lang}"
  fi
}

lms_msg() {
  local en="$1"
  local zh="${2:-$1}"

  if lms_is_zh; then
    printf '%s\n' "${zh}"
  else
    printf '%s\n' "${en}"
  fi
}
