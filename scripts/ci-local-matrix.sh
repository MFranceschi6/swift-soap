#!/bin/zsh
set -euo pipefail
setopt typesetsilent

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
REPORT_ROOT="$ROOT_DIR/.cursor/report/local-matrix"
RUN_DATE=$(date +%F)
RUN_ID=$(date +%Y%m%d-%H%M%S)
RUN_DIR="$REPORT_ROOT/$RUN_DATE/$RUN_ID"
mkdir -p "$RUN_DIR"
ln -sfn "$RUN_DIR" "$REPORT_ROOT/latest"

SWIFTLY_BIN="${SWIFTLY_BIN:-$HOME/.swiftly/bin/swiftly}"
SWIFTLY_CONFIG="${SWIFTLY_CONFIG:-$HOME/.swiftly/config.json}"

LANES=(
  runtime-5.4
  tooling-5.6-plus
  quality-5.10
  latest
)

usage() {
  cat <<'USAGE'
Usage:
  ./scripts/ci-local-matrix.sh
  ./scripts/ci-local-matrix.sh --lane <runtime-5.4|tooling-5.6-plus|quality-5.10|latest>
  ./scripts/ci-local-matrix.sh <runtime-5.4|tooling-5.6-plus|quality-5.10|latest>
  ./scripts/ci-local-matrix.sh --list-toolchains

Environment:
  SWIFTLY_BIN     Path to swiftly binary (default: ~/.swiftly/bin/swiftly)
  SWIFTLY_CONFIG  Path to swiftly config.json (default: ~/.swiftly/config.json)
USAGE
}

is_valid_lane() {
  case "$1" in
    runtime-5.4|tooling-5.6-plus|quality-5.10|latest) return 0 ;;
    *) return 1 ;;
  esac
}

version_ge() {
  local left="$1"
  local right="$2"
  local IFS=.
  local -a left_parts right_parts
  left_parts=(${=left})
  right_parts=(${=right})

  local i
  for i in 1 2 3; do
    local l=${left_parts[$i]:-0}
    local r=${right_parts[$i]:-0}
    if (( l > r )); then
      return 0
    fi
    if (( l < r )); then
      return 1
    fi
  done

  return 0
}

version_lt() {
  ! version_ge "$1" "$2"
}

lane_accepts_version() {
  local lane="$1"
  local version="$2"

  case "$lane" in
    runtime-5.4)
      [[ "$version" == 5.4 || "$version" == 5.4.* ]]
      ;;
    tooling-5.6-plus)
      [[ "$version" == 5.6* || "$version" == 5.7* || "$version" == 5.8* || "$version" == 5.9* ]]
      ;;
    quality-5.10)
      [[ "$version" == 5.10* ]]
      ;;
    latest)
      local major="${version%%.*}"
      (( major >= 6 ))
      ;;
    *)
      return 1
      ;;
  esac
}

load_swiftly_versions() {
  if [[ ! -x "$SWIFTLY_BIN" ]]; then
    echo "swiftly not found or not executable at: $SWIFTLY_BIN" >&2
    return 1
  fi

  if [[ ! -f "$SWIFTLY_CONFIG" ]]; then
    echo "swiftly config not found at: $SWIFTLY_CONFIG" >&2
    return 1
  fi

  typeset -ga SWIFTLY_VERSIONS
  SWIFTLY_VERSIONS=()

  SWIFTLY_IN_USE=$(sed -nE 's/^[[:space:]]*"inUse"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/p' "$SWIFTLY_CONFIG" | head -n 1)

  local version
  while read -r version; do
    [[ -n "$version" ]] || continue
    SWIFTLY_VERSIONS+=("$version")
  done < <(
    sed -n '/"installedToolchains"[[:space:]]*:/,/\]/p' "$SWIFTLY_CONFIG" \
      | sed -nE 's/.*"([0-9]+\.[0-9]+(\.[0-9]+)?)".*/\1/p'
  )

  if (( ${#SWIFTLY_VERSIONS[@]} == 0 )); then
    echo "no installed swiftly toolchains found in: $SWIFTLY_CONFIG" >&2
    return 1
  fi

  return 0
}

select_lane_version() {
  local lane="$1"
  local best=""
  local candidate

  for candidate in "${SWIFTLY_VERSIONS[@]}"; do
    if ! lane_accepts_version "$lane" "$candidate"; then
      continue
    fi

    if [[ -z "$best" ]] || version_lt "$best" "$candidate"; then
      best="$candidate"
    fi
  done

  if [[ -z "$best" ]]; then
    return 1
  fi

  SELECTED_VERSION="$best"
  return 0
}

list_toolchains() {
  load_swiftly_versions

  echo "swiftly toolchains:"
  local version
  for version in "${SWIFTLY_VERSIONS[@]}"; do
    if [[ -n "${SWIFTLY_IN_USE:-}" && "$version" == "$SWIFTLY_IN_USE" ]]; then
      echo "  - $version (in use)"
    else
      echo "  - $version"
    fi
  done
}

run_swift() {
  "$SWIFTLY_BIN" run swift "$@"
}

run_lane() {
  local lane="$1"

  if ! select_lane_version "$lane"; then
    echo "[lane:$lane] no installed swiftly toolchain matches this lane"
    return 2
  fi

  local version="$SELECTED_VERSION"
  local build_dir="$ROOT_DIR/.build/local-matrix/$lane/$version"
  local log_file="$RUN_DIR/$lane.log"

  mkdir -p "$build_dir"
  : > "$log_file"

  {
    echo "[lane:$lane] swiftly_version=$version"
    echo "[lane:$lane] build_dir=$build_dir"
  } | tee -a "$log_file"

  set +e
  (
    set -euo pipefail
    cd "$ROOT_DIR"

    "$SWIFTLY_BIN" use "$version" --global-default -y
    run_swift --version

    case "$lane" in
      runtime-5.4)
        run_swift package --disable-sandbox --package-path "$ROOT_DIR" --build-path "$build_dir" describe > "$RUN_DIR/runtime-5.4-package-describe.txt"
        ;;
      tooling-5.6-plus)
        run_swift build --disable-sandbox --package-path "$ROOT_DIR" --build-path "$build_dir" -c debug --jobs 1
        run_swift test --disable-sandbox --package-path "$ROOT_DIR" --build-path "$build_dir" --jobs 1 --parallel --num-workers 1
        ;;
      quality-5.10)
        if ! command -v swiftlint >/dev/null 2>&1; then
          echo "swiftlint not found in PATH"
          exit 127
        fi
        swiftlint lint
        run_swift build --disable-sandbox --package-path "$ROOT_DIR" --build-path "$build_dir" -c debug --jobs 1
        run_swift test --disable-sandbox --package-path "$ROOT_DIR" --build-path "$build_dir" --enable-code-coverage --jobs 1 --parallel --num-workers 1
        ;;
      latest)
        run_swift build --disable-sandbox --package-path "$ROOT_DIR" --build-path "$build_dir" -c debug --jobs 1
        run_swift test --disable-sandbox --package-path "$ROOT_DIR" --build-path "$build_dir" --jobs 1 --parallel --num-workers 1
        ;;
    esac
  ) > >(tee -a "$log_file") 2> >(tee -a "$log_file" >&2)
  local lane_rc=$?
  set -e

  if [[ $lane_rc -ne 0 ]]; then
    echo "[lane:$lane] failed (exit=$lane_rc)" | tee -a "$log_file"
    return $lane_rc
  fi

  echo "[lane:$lane] completed" | tee -a "$log_file"
}

SELECTED_LANE=""
LIST_TOOLCHAINS="false"

if [[ $# -gt 0 ]]; then
  case "$1" in
    --help|-h)
      usage
      exit 0
      ;;
    --list-toolchains)
      LIST_TOOLCHAINS="true"
      ;;
    --lane)
      if [[ -z "${2:-}" ]]; then
        usage
        exit 1
      fi
      SELECTED_LANE="$2"
      ;;
    *)
      SELECTED_LANE="$1"
      ;;
  esac
fi

if [[ "$LIST_TOOLCHAINS" == "true" ]]; then
  list_toolchains
  exit 0
fi

if [[ -n "$SELECTED_LANE" ]] && ! is_valid_lane "$SELECTED_LANE"; then
  echo "Unknown lane '$SELECTED_LANE'. Allowed: runtime-5.4, tooling-5.6-plus, quality-5.10, latest"
  exit 1
fi

load_swiftly_versions

typeset -a lanes_to_run
if [[ -n "$SELECTED_LANE" ]]; then
  lanes_to_run=("$SELECTED_LANE")
else
  lanes_to_run=("${LANES[@]}")
fi

typeset -A lane_results
overall_rc=0

for lane in "${lanes_to_run[@]}"; do
  if run_lane "$lane"; then
    lane_results[$lane]="ok"
  else
    lane_results[$lane]="failed"
    overall_rc=1
  fi
done

echo "Summary:"
for lane in "${lanes_to_run[@]}"; do
  echo "  - $lane: ${lane_results[$lane]}"
done

echo "Logs: $RUN_DIR"
exit $overall_rc
