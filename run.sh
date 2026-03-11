#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$ROOT_DIR"

find_windows_flutter_bat() {
  if [[ -n "${FLUTTER_BAT_PATH:-}" ]]; then
    if [[ "${FLUTTER_BAT_PATH}" == /mnt/* ]]; then
      wslpath -w "${FLUTTER_BAT_PATH}"
    else
      echo "${FLUTTER_BAT_PATH}"
    fi
    return 0
  fi

  if command -v powershell.exe >/dev/null 2>&1; then
    local flutter_path
    flutter_path=$(powershell.exe -NoProfile -Command "(Get-Command flutter.bat -ErrorAction SilentlyContinue).Path")
    if [[ -n "$flutter_path" ]]; then
      echo "$flutter_path" | tr -d '\r'
      return 0
    fi
  fi
  return 1
}

has_native_flutter() {
  command -v flutter >/dev/null 2>&1
}

native_flutter_is_windows_mount() {
  if ! has_native_flutter; then
    return 1
  fi
  local flutter_bin
  flutter_bin="$(command -v flutter)"
  [[ "$flutter_bin" == /mnt/c/* ]]
}

run_flutter_in_dir() {
  local dir="$1"
  shift

  if has_native_flutter && ! native_flutter_is_windows_mount; then
    (
      cd "$dir"
      flutter "$@"
    )
    return
  fi

  local win_flutter_bat
  if win_flutter_bat=$(find_windows_flutter_bat); then
    if ! command -v wslpath >/dev/null 2>&1; then
      echo "wslpath is required for Windows Flutter fallback."
      exit 1
    fi
    local win_dir
    win_dir="$(wslpath -w "$dir")"
    local tmp_args
    tmp_args="$(mktemp)"
    printf '%s\n' "$@" > "$tmp_args"
    local win_args
    win_args="$(wslpath -w "$tmp_args")"
    powershell.exe -NoProfile -Command "Set-Location '$win_dir'; \$argList = Get-Content -LiteralPath '$win_args'; if (\$argList -is [string]) { \$argList = @(\$argList) }; & '$win_flutter_bat' @argList"
    rm -f "$tmp_args"
    return
  fi

  echo "Flutter not found."
  echo "Install Flutter or make sure one of these is available:"
  echo "  - native 'flutter' command in PATH"
  echo "  - 'flutter.bat' in Windows PATH (for WSL fallback)"
  echo "  - FLUTTER_BAT_PATH environment variable set to Windows flutter.bat path"
  exit 1
}

android_apk_path() {
  local dir="$1"
  echo "$dir/build/app/outputs/flutter-apk/app-debug.apk"
}

is_zip_magic() {
  local file_path="$1"
  if [[ ! -f "$file_path" ]]; then
    return 1
  fi
  local magic
  magic="$(head -c 2 "$file_path" 2>/dev/null | od -An -t x1 | tr -d ' \n' || true)"
  [[ "$magic" == "504b" ]]
}

maybe_fix_broken_android_apk() {
  local dir="$1"
  local apk
  apk="$(android_apk_path "$dir")"
  if [[ -f "$apk" ]] && ! is_zip_magic "$apk"; then
    echo
    echo "-----------------------------------------"
    echo " Detected broken APK (not a ZIP): $apk"
    echo " Cleaning build artifacts..."
    echo "-----------------------------------------"
    rm -f "$apk" || true
    rm -rf "$dir/build" || true
    run_flutter_in_dir "$dir" clean || true
    echo "Done."
    echo
  fi
}

main() {
  if [[ ! -f "$APP_DIR/pubspec.yaml" ]]; then
    echo "pubspec.yaml not found in: $APP_DIR"
    exit 1
  fi

  echo
  echo "========================================="
  echo " Gold Mine Trolls"
  echo "========================================="

  echo "[1/3] Installing dependencies..."
  run_flutter_in_dir "$APP_DIR" pub get

  echo "[2/3] Checking devices..."
  run_flutter_in_dir "$APP_DIR" devices || true

  maybe_fix_broken_android_apk "$APP_DIR"

  echo "[3/3] Running app..."
  local run_log
  run_log="$(mktemp)"
  set +e
  run_flutter_in_dir "$APP_DIR" run "$@" 2>&1 | tee "$run_log"
  local run_exit="${PIPESTATUS[0]}"
  set -e

  if [[ "$run_exit" -eq 0 ]]; then
    rm -f "$run_log" || true
    exit 0
  fi

  if ! is_zip_magic "$(android_apk_path "$APP_DIR")"; then
    echo
    echo "-----------------------------------------"
    echo " Flutter run failed and APK looks corrupted."
    echo " Retrying after clean..."
    echo "-----------------------------------------"
    maybe_fix_broken_android_apk "$APP_DIR"
    run_flutter_in_dir "$APP_DIR" run "$@"
    exit $?
  fi

  if grep -q "Building with plugins requires symlink support" "$run_log" 2>/dev/null; then
    echo
    echo "-----------------------------------------"
    echo " Symlink support error detected."
    echo
    echo " Fix options:"
    echo "  - Enable Windows Developer Mode:"
    echo "      start ms-settings:developers"
    echo "  - OR move the project to the WSL ext4 filesystem (e.g. under /home/<user>/...)"
    echo "    and use Linux Flutter there (avoids /mnt/c symlink limitations)."
    echo "-----------------------------------------"
    echo
  fi

  rm -f "$run_log" || true
  exit "$run_exit"
}

main "$@"
