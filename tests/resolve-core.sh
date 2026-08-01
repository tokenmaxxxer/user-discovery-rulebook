#!/usr/bin/env bash
# Resolves CLAUDE_PLUGIN_ROOT_CORE so the gate test suites can run
# standalone (`bash tests/*.sh` outside a Claude Code session where a
# plugin installer would normally set it), without vendoring
# core/hooks/lib/gate-lib.sh|py into this repo (canon reference-only, per
# docs/handbooks/canon-scripts.md).
#
# Honors an already-exported CLAUDE_PLUGIN_ROOT_CORE first (a real
# install, or a developer's own local `core` checkout). Otherwise
# shallow-clones tokenmaxxxer-core into a cache directory (once) and
# points at its core/ subdirectory. Sourced by each test suite and by
# tests/run-all-gate-tests.sh.
if [ -z "${CLAUDE_PLUGIN_ROOT_CORE:-}" ]; then
  _resolve_core_cache="${TMPDIR:-/tmp}/tokenmaxxxer-core-canon-cache"
  if [ ! -f "$_resolve_core_cache/core/hooks/lib/gate-lib.sh" ]; then
    rm -rf "$_resolve_core_cache"
    git clone -q --depth 1 https://github.com/tokenmaxxxer/tokenmaxxxer-core.git \
      "$_resolve_core_cache" >/dev/null 2>&1 || true
  fi
  if [ -f "$_resolve_core_cache/core/hooks/lib/gate-lib.sh" ]; then
    export CLAUDE_PLUGIN_ROOT_CORE="$_resolve_core_cache/core"
  fi
  unset _resolve_core_cache
fi
