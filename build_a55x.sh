#!/usr/bin/bash

# Kernel compilation script for Galaxy A55x
set -euo pipefail

# Color Definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Initial configuration
LOGS_DIR="build_logs"
LOG_FILE="${LOGS_DIR}/build_$(date +%Y%m%d_%H%M%S).log"
BAZEL="tools/bazel"
TARGET="//projects/s5e8845:s5e8845_user_dist"
CLEAN=0
LTO="thin"
ANYKERNEL=0
VERSION=$(date +%Y%m%d)
JOBS=$(nproc)

# Bazel options
BAZEL_OPTS=(
  "--nocheck_bzl_visibility"
  "--config=stamp"
  "--sandbox_debug"
  "--verbose_failures"
)

# Logging function
log_message() {
  local LEVEL="$1"
  local MESSAGE="$2"
  local TIMESTAMP
  TIMESTAMP=$(date +'%Y-%m-%d %H:%M:%S')

  local COLOR=$NC
  case "$LEVEL" in
    "INFO")  COLOR=$GREEN ;;
    "WARN")  COLOR=$YELLOW ;;
    "ERROR") COLOR=$RED ;;
  esac

  # Terminal output with color
  echo -e "${COLOR}[$TIMESTAMP] [$LEVEL] $MESSAGE${NC}"

  # File output without color (plain text)
  echo "[$TIMESTAMP] [$LEVEL] $MESSAGE" >> "$LOG_FILE"
}

# Error handling
error_handler() {
  log_message "ERROR" "Build failed on line $1"
  exit 1
}
trap 'error_handler $LINENO' ERR

# Display usage
show_help() {
  cat << EOF
Usage: $0 [options]

Options:
  -h,  --help           Show this help message (must be used alone)
  -c,  --clean          Clean build directory before building
  -j,  --jobs [NUM]     Set number of build jobs (default: $JOBS)
  -l,  --lto [TYPE]     Set LTO type (none, thin, full) [default: thin]
  -ak, --anykernel      Package kernel with AnyKernel3
  -v,  --verbose        Enable verbose Bazel output
EOF
}

# AnyKernel3 Packaging
package_anykernel() {
  local ANYKERNEL_DIR="AnyKernel3"
  local ANYKERNEL_REPO="https://github.com/exynos1480/AnyKernel3"
  local IMAGE="out/s5e8845/dist/Image"

  log_message "INFO" "Starting AnyKernel3 packaging..."

  if [ ! -d "$ANYKERNEL_DIR" ]; then
    log_message "INFO" "Cloning AnyKernel3..."
    git clone "$ANYKERNEL_REPO" "$ANYKERNEL_DIR"
  else
    log_message "INFO" "Updating AnyKernel3..."
    (cd "$ANYKERNEL_DIR" && git pull)
  fi

  if [ ! -f "$IMAGE" ]; then
    log_message "ERROR" "Kernel image not found at $IMAGE"
    return 1
  fi

  cp "$IMAGE" "$ANYKERNEL_DIR/Image"
  cd "$ANYKERNEL_DIR"
  zip -r9 "../Kernel-A55x-$VERSION.zip" ./* -x .git .gitignore
  cd ..
  log_message "INFO" "Packaging complete: Kernel-A55x-$VERSION.zip"
}

# Argument exclusivity check for help
for arg in "$@"; do
  if [[ "$arg" == "-h" || "$arg" == "--help" ]]; then
    if [ "$#" -gt 1 ]; then
      show_help
      exit 1
    fi
    show_help
    exit 0
  fi
done

# Parsing logic
while [[ $# -gt 0 ]]; do
  case $1 in
    -c | --clean)
      CLEAN=1
      shift
      ;;
    -l | --lto)
      LTO="$2"
      if [[ ! "$LTO" =~ ^(none|thin|full)$ ]]; then
        log_message "ERROR" "Invalid LTO type: $LTO. Use: none, thin, full"
        exit 1
      else
        BUILD_OPTS+=("--lto=$LTO")
      fi
      shift 2
      ;;
    -v | --verbose)
      BAZEL_OPTS+=("--debug_make_verbosity=I")
      shift
      ;;
    -j | --jobs)
      JOBS="$2"
      shift 2
      ;;
    -ak | --anykernel)
      ANYKERNEL=1
      shift
      ;;
    *)
      log_message "ERROR" "Unknown argument: $1"
      show_help
      exit 1
      ;;
  esac
done

# Finalize Bazel options
BAZEL_OPTS+=("--jobs=$JOBS")

# Execution sequence
log_message "INFO" "Starting build for Galaxy A55x (LTO=$LTO, Jobs=$JOBS)"

if [ "$CLEAN" -eq 1 ]; then
  log_message "INFO" "Cleaning build environment..."
  $BAZEL clean --expunge
fi

log_message "INFO" "Running Bazel build..."

mkdir -p "$LOGS_DIR"

# Run Bazel
$BAZEL run "${BAZEL_OPTS[@]}" "$TARGET" 2>&1 | tee >(sed 's/\x1b\[[0-9;]*m//g' >> "$LOG_FILE")

if [ "$ANYKERNEL" -eq 1 ]; then
  package_anykernel
fi

log_message "INFO" "Process finished successfully."
