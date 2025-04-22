#!/bin/bash

# Configuration
BAZEL_TOOL="tools/bazel"
PROJECT_TARGET="//projects/s5e8845:s5e8845_user_dist"
LOG_DIR="logs"
LOG_FILE="${LOG_DIR}/build_$(date +%Y%m%d_%H%M%S).log"
ANYKERNEL_DIR="AnyKernel3"
ANYKERNEL_REPO="https://github.com/exynos1480-dev/AnyKernel3.git"

# Default build options
BUILD_OPTS=(
    "--nocheck_bzl_visibility"
    "--config=stamp"
    "--sandbox_debug"
    "--verbose_failures"
    "--debug_make_verbosity=I"
)

# Setup logging
setup_logging() {
    mkdir -p "$LOG_DIR"
    # Create the log file and add header
    echo "=== Build started at $(date) ===" > "$LOG_FILE"
    echo "Command: $0 $*" >> "$LOG_FILE"
    echo "==================================" >> "$LOG_FILE"
}

# Function to log messages to both console and file
log_message() {
    echo "$1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# Setup AnyKernel3
setup_anykernel() {
    if [ ! -d "$ANYKERNEL_DIR" ]; then
        log_message "Cloning AnyKernel3 repository..."
        git clone "$ANYKERNEL_REPO" "$ANYKERNEL_DIR" 2>&1 | tee -a "$LOG_FILE"
    else
        log_message "Updating AnyKernel3 repository..."
        (cd "$ANYKERNEL_DIR" && git pull) 2>&1 | tee -a "$LOG_FILE"
    fi
}

# Package kernel with AnyKernel3
package_kernel() {
    local kernel_image="$1"
    local version="$2"
    
    if [ ! -f "$kernel_image" ]; then
        log_message "Error: Kernel image not found at $kernel_image"
        return 1
    fi

    log_message "Packaging kernel with AnyKernel3..."
    
    # Create package directory
    local package_dir="$ANYKERNEL_DIR/package"
    mkdir -p "$package_dir"
    
    # Copy kernel image
    cp "$kernel_image" "$ANYKERNEL_DIR/Image"
    
    # Create zip package
    (cd "$ANYKERNEL_DIR" && \
        zip -r9 "package/A55-kernel-${version}.zip" * -x .git README.md *placeholder package* 2>&1) | tee -a "$LOG_FILE"
    
    log_message "Kernel package created: $ANYKERNEL_DIR/package/A55-kernel-${version}.zip"
}

# Help message
show_help() {
    echo "Usage: $0 [options]"
    echo "Build script for Galaxy A55 kernel"
    echo ""
    echo "Options:"
    echo "  -h, --help     Show this help message"
    echo "  -c, --clean    Clean build directory before building"
    echo "  -j N           Set number of build jobs (default: number of CPU cores)"
    echo "  -l, --last-log Show the last build log"
    echo "  --lto=TYPE     Set LTO type (none, thin, full) [default: thin]"
    echo "  -p, --package  Package kernel with AnyKernel3"
    echo "  -v VERSION     Specify kernel version for package name"
}

# Error handling
set -e  # Exit on error
trap 'log_message "Error: Build failed on line $LINENO"; exit 1' ERR

# Parse command line arguments
CLEAN_BUILD=0
LTO_TYPE="thin"  # Default LTO type
PACKAGE_KERNEL=0
KERNEL_VERSION=$(date +%Y%m%d)

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -c|--clean)
            CLEAN_BUILD=1
            shift
            ;;
        -j)
            BUILD_OPTS+=("--jobs=$2")
            shift 2
            ;;
        -l|--last-log)
            if [ -d "$LOG_DIR" ]; then
                latest_log=$(ls -t "$LOG_DIR"/*.log 2>/dev/null | head -n1)
                if [ -n "$latest_log" ]; then
                    cat "$latest_log"
                else
                    echo "No log files found"
                fi
            else
                echo "Log directory does not exist"
            fi
            exit 0
            ;;
        --lto=*)
            LTO_TYPE="${1#*=}"
            if [[ "$LTO_TYPE" =~ ^(none|thin|full)$ ]]; then
                log_message "Setting LTO type to: $LTO_TYPE"
            else
                echo "Error: Invalid LTO type. Valid options are: none, thin, full"
                exit 1
            fi
            shift
            ;;
        -p|--package)
            PACKAGE_KERNEL=1
            shift
            ;;
        -v)
            KERNEL_VERSION="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Initialize logging
setup_logging "$@"

# Add LTO option if not 'none'
if [ "$LTO_TYPE" != "none" ]; then
    BUILD_OPTS+=("--lto=$LTO_TYPE")
    log_message "Using $LTO_TYPE LTO"
else
    log_message "LTO disabled"
fi

# Setup AnyKernel3 if packaging is requested
if [ "$PACKAGE_KERNEL" -eq 1 ]; then
    setup_anykernel
fi

# Clean if requested
if [ "$CLEAN_BUILD" -eq 1 ]; then
    log_message "Cleaning build directory..."
    $BAZEL_TOOL clean 2>&1 | tee -a "$LOG_FILE"
fi

# Execute build
log_message "Starting build with options: ${BUILD_OPTS[*]}"
# Use tee to capture output both to console and log file
$BAZEL_TOOL run "${BUILD_OPTS[@]}" "$PROJECT_TARGET" 2>&1 | tee -a "$LOG_FILE"

# Package kernel if requested
if [ "$PACKAGE_KERNEL" -eq 1 ]; then
    # Assuming the kernel image location - adjust this path as needed
    KERNEL_IMAGE="out/s5e8845_user/dist/Image"
    package_kernel "$KERNEL_IMAGE" "$KERNEL_VERSION"
fi

# Log completion
log_message "Build completed successfully"
log_message "Log file: $LOG_FILE"
