#!/usr/bin/env bash
. "${CLAUDE_PLUGIN_ROOT_CORE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../core" && pwd -P)}/hooks/lib/role-directive.sh"
core_role_directive "YOU DECIDE: 이 문제가 실제 사용자의 고통인가" "USE WHEN: 가설 검증을 위해 사용자 인터뷰가 필요할 때" "PRODUCES: interview script, per-interview evidence log, pain-confirmed|not-confirmed verdict" "HAND-OFF: 검증된 가설을 스펙화하면 → requirements-engineering"
