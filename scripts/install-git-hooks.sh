#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
hooks_dir="${repo_root}/.githooks"

mkdir -p "${hooks_dir}"
chmod +x "${hooks_dir}/pre-commit" "${hooks_dir}/commit-msg" 2>/dev/null || true
chmod +x "${repo_root}/scripts/commit-gate.sh"

git config core.hooksPath .githooks
echo "Git hooks installed. Active hooks path: .githooks"
