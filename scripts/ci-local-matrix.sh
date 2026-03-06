#!/bin/zsh
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
REPORT_ROOT="$ROOT_DIR/.cursor/report/local-matrix"
RUN_DATE=$(date +%F)
RUN_ID=$(date +%Y%m%d-%H%M%S)
RUN_DIR="$REPORT_ROOT/$RUN_DATE/$RUN_ID"
mkdir -p "$RUN_DIR"
ln -sfn "$RUN_DIR" "$REPORT_ROOT/latest"

usage() {
  cat <<'EOF'
Usage:
  ./scripts/ci-local-matrix.sh
  ./scripts/ci-local-matrix.sh --lane <runtime-5.4|tooling-5.6-plus|quality-5.10|latest>
  ./scripts/ci-local-matrix.sh <runtime-5.4|tooling-5.6-plus|quality-5.10|latest>
EOF
}

is_valid_lane() {
  case "$1" in
    runtime-5.4|tooling-5.6-plus|quality-5.10|latest) return 0 ;;
    *) return 1 ;;
  esac
}

SELECTED_LANE="${1:-}"
if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  usage
  exit 0
fi

if [[ "${1:-}" == "--lane" ]]; then
  if [[ -z "${2:-}" ]]; then
    usage
    exit 1
  fi
  SELECTED_LANE="$2"
fi

if [[ -n "$SELECTED_LANE" ]] && ! is_valid_lane "$SELECTED_LANE"; then
  echo "Unknown lane '$SELECTED_LANE'. Allowed: runtime-5.4, tooling-5.6-plus, quality-5.10, latest"
  exit 1
fi

run_lane() { # lane image lane_command platform timeout_seconds max_retries
  local lane="$1"
  local image="$2"
  local lane_command="$3"
  local platform="${4:-}"
  local timeout_seconds="${5:-300}"
  local max_retries="${6:-0}"

  if [[ -n "$SELECTED_LANE" && "$SELECTED_LANE" != "$lane" ]]; then
    return 0
  fi

  local log_file="$RUN_DIR/${lane}.log"
  : > "$log_file"
  echo "[lane:$lane] image=$image platform=${platform:-default} timeout=${timeout_seconds}s retries=$max_retries run_id=$RUN_ID" | tee -a "$log_file"

  local platform_args=()
  if [[ -n "$platform" ]]; then
    platform_args=(--platform "$platform")
  fi

  local attempt=1
  local max_attempts=$((max_retries + 1))
  while (( attempt <= max_attempts )); do
    local scratch_path="/tmp/swiftpm-${lane}-${RUN_ID}-a${attempt}"
    echo "[lane:$lane] attempt=$attempt/$max_attempts scratch_path=$scratch_path" | tee -a "$log_file"

    set +e
    docker run --rm \
      "${platform_args[@]}" \
      -v "$ROOT_DIR:/workspace" \
      -w /workspace \
      "$image" \
      bash -lc "set -euo pipefail; \
        apt-get update >/dev/null; \
        apt-get install -y libxml2-dev >/dev/null; \
        rm -rf /tmp/swift-lane-workspace; \
        mkdir -p /tmp/swift-lane-workspace; \
        cp -a /workspace/Package*.swift /tmp/swift-lane-workspace/; \
        cp -a /workspace/Sources /tmp/swift-lane-workspace/; \
        cp -a /workspace/Tests /tmp/swift-lane-workspace/; \
        cd /tmp/swift-lane-workspace; \
        export SWIFTPM_SCRATCH_PATH='$scratch_path'; \
        swift --version; \
        timeout ${timeout_seconds}s bash -lc \"$lane_command\"" >> "$log_file" 2>&1
    local exit_code=$?
    set -e

    if [[ $exit_code -eq 0 ]]; then
      echo "[lane:$lane] completed (attempt=$attempt/$max_attempts)" | tee -a "$log_file"
      return 0
    fi

    if [[ $exit_code -eq 124 ]]; then
      echo "[lane:$lane] timeout after ${timeout_seconds}s (attempt=$attempt/$max_attempts)" | tee -a "$log_file"
    else
      echo "[lane:$lane] failed with exit code $exit_code (attempt=$attempt/$max_attempts)" | tee -a "$log_file"
    fi

    if (( attempt == max_attempts )); then
      return $exit_code
    fi

    echo "[lane:$lane] retrying..." | tee -a "$log_file"
    attempt=$((attempt + 1))
  done
}

run_lane \
  "runtime-5.4" \
  "swift:5.4" \
  "swift package describe > /tmp/runtime-5.4-package-describe.txt" \
  "linux/amd64" \
  "120" \
  "0"

run_lane \
  "tooling-5.6-plus" \
  "swift:5.6" \
  "swift build -c debug --jobs 1 && swift test --jobs 1 --parallel --num-workers 1" \
  "linux/amd64" \
  "300" \
  "0"

run_lane \
  "quality-5.10" \
  "swift:5.10" \
  "swift test --scratch-path \"\$SWIFTPM_SCRATCH_PATH\" --enable-code-coverage --jobs 1 --parallel --num-workers 1" \
  "" \
  "300" \
  "0"

run_lane \
  "latest" \
  "swift:6.2" \
  "swift test --scratch-path \"\$SWIFTPM_SCRATCH_PATH\" --enable-code-coverage --jobs 1 --parallel --num-workers 1" \
  "" \
  "300" \
  "1"

if [[ -n "$SELECTED_LANE" ]]; then
  printf 'Local lane completed: %s\n' "$SELECTED_LANE"
else
  printf 'Local matrix completed: runtime-5.4, tooling-5.6-plus, quality-5.10, latest\n'
fi

printf 'Logs: %s\n' "$RUN_DIR"
