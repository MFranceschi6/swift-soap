#!/bin/zsh
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
LOG_DIR="$ROOT_DIR/.cursor/report/2026-03-05-epic-3-runtime-api-split/local-matrix"
mkdir -p "$LOG_DIR"

run_lane() {
  local lane="$1"
  local image="$2"
  local lane_command="$3"
  local platform="${4:-}"

  local log_file="$LOG_DIR/${lane}.log"
  echo "[lane:$lane] image=$image platform=${platform:-default}" | tee "$log_file"

  local platform_args=()
  if [[ -n "$platform" ]]; then
    platform_args=(--platform "$platform")
  fi

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
      swift --version; \
      $lane_command" >> "$log_file" 2>&1

  echo "[lane:$lane] completed" | tee -a "$log_file"
}

run_lane \
  "runtime-5.4" \
  "swift:5.4" \
  "swift package describe > /tmp/runtime-5.4-package-describe.txt" \
  "linux/amd64"

run_lane \
  "tooling-5.6-plus" \
  "swift:5.6" \
  "swift build --scratch-path /tmp/swiftpm-tooling-56 -c debug" \
  "linux/amd64"

run_lane \
  "quality-5.10" \
  "swift:5.10" \
  "swift test --scratch-path /tmp/swiftpm-quality-510 --enable-code-coverage"

run_lane \
  "latest" \
  "swift:6.2" \
  "swift test --scratch-path /tmp/swiftpm-latest --enable-code-coverage"

printf 'Local matrix completed: runtime-5.4, tooling-5.6-plus, quality-5.10, latest\n'
