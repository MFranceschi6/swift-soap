#!/usr/bin/env bash
set -euo pipefail

readonly GITMOJI_PATTERN='^(:[a-z0-9_+-]+:|[^ -~])[[:space:]]+.+'
readonly TYPE_DECL_PATTERN='^(public |internal |private |fileprivate )?(final )?(class|struct|enum|protocol)[[:space:]]+'
readonly EXTENSION_DECL_PATTERN='^extension[[:space:]]+'

# Files that predate the one-type-per-file convention and are exempt from the
# multiple-top-level-type check (they are still linted by SwiftLint).
readonly LEGACY_MULTI_TYPE_EXEMPT=(
  "Sources/SwiftSOAPCore/SOAPBinding.swift"
  "Sources/SwiftSOAPCodeGenCore/CodeGenerationIR.swift"
  "Sources/SwiftSOAPCodeGenCore/CodeGenerator.swift"
  "Sources/SwiftSOAPXML/XMLRootNode.swift"
)

fail() {
  echo "commit gate failed: $*" >&2
  exit 1
}

staged_files() {
  git diff --cached --name-only --diff-filter=ACMR
}

run_swiftlint_for_staged_swift_files() {
  local swift_files=()
  local file
  while IFS= read -r file; do
    [[ -n "${file}" ]] || continue
    swift_files+=("${file}")
  done < <(staged_files | rg '\.swift$' || true)
  if [[ ${#swift_files[@]} -eq 0 ]]; then
    return 0
  fi

  command -v swiftlint >/dev/null 2>&1 || fail "swiftlint is required but not available in PATH."

  export SCRIPT_INPUT_FILE_COUNT="${#swift_files[@]}"
  for index in "${!swift_files[@]}"; do
    export "SCRIPT_INPUT_FILE_${index}=${swift_files[$index]}"
  done

  echo "commit gate: running swiftlint on staged Swift files (${#swift_files[@]} files)"
  swiftlint lint --use-script-input-files --no-cache
}

validate_staged_source_file_structure() {
  local source_files=()
  local source_file
  while IFS= read -r source_file; do
    [[ -n "${source_file}" ]] || continue
    source_files+=("${source_file}")
  done < <(staged_files | rg '^Sources/.*\.swift$' || true)
  if [[ ${#source_files[@]} -eq 0 ]]; then
    return 0
  fi

  for file in "${source_files[@]}"; do
    [[ -f "${file}" ]] || continue

    local basename_no_ext
    basename_no_ext="$(basename "${file}" .swift)"
    local type_decl_lines
    type_decl_lines="$(rg -n "${TYPE_DECL_PATTERN}" "${file}" || true)"
    local type_decl_count
    # Deduplicate type names: #if/#else conditional compilation may declare the
    # same type in each branch; count unique names only.
    type_decl_count="$(printf '%s\n' "${type_decl_lines}" | sed '/^$/d' | \
      sed -E 's/^[0-9]+:(public |internal |private |fileprivate )?(final )?(class|struct|enum|protocol)[[:space:]]+([A-Za-z_][A-Za-z0-9_]*).*/\4/' | \
      sort -u | wc -l | tr -d ' ')"

    if [[ "${basename_no_ext}" == *"+"* ]]; then
      local extension_decl_count
      extension_decl_count="$(rg -n "${EXTENSION_DECL_PATTERN}" "${file}" | wc -l | tr -d ' ')"
      if [[ "${extension_decl_count}" -eq 0 ]]; then
        fail "file ${file} uses '+' naming but does not declare any extension."
      fi
      continue
    fi

    if [[ "${type_decl_count}" -gt 1 ]]; then
      if printf '%s\n' "${LEGACY_MULTI_TYPE_EXEMPT[@]}" | grep -qxF "${file}"; then
        continue  # legacy file exempt from one-type-per-file rule
      fi
      fail "file ${file} declares multiple top-level types; split declaration/logic per project conventions."
    fi

    if [[ "${type_decl_count}" -eq 1 ]]; then
      local declared_type_name
      declared_type_name="$(printf '%s\n' "${type_decl_lines}" | head -n 1 | sed -E 's/.*(class|struct|enum|protocol)[[:space:]]+([A-Za-z_][A-Za-z0-9_]*).*/\2/')"
      if [[ -n "${declared_type_name}" && "${declared_type_name}" != "${basename_no_ext}" ]]; then
        fail "file ${file} should match declared type name ${declared_type_name}.swift."
      fi
    fi
  done
}

validate_commit_message() {
  local message_file="$1"
  [[ -f "${message_file}" ]] || fail "commit message file not found: ${message_file}"
  local first_line
  first_line="$(head -n 1 "${message_file}" | tr -d '\r')"

  if [[ ! "${first_line}" =~ ${GITMOJI_PATTERN} ]]; then
    fail "commit message must start with a gitmoji (emoji or :gitmoji: shortcode), then space, then message."
  fi
}

main() {
  local mode="${1:-}"
  case "${mode}" in
    --pre-commit)
      run_swiftlint_for_staged_swift_files
      validate_staged_source_file_structure
      ;;
    --commit-msg)
      local message_file="${2:-}"
      [[ -n "${message_file}" ]] || fail "--commit-msg requires the commit message file path."
      validate_commit_message "${message_file}"
      ;;
    *)
      fail "unknown mode '${mode}'. Supported: --pre-commit | --commit-msg"
      ;;
  esac
}

main "$@"
