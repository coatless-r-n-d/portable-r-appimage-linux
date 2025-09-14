#!/bin/bash

# R AppImage Builder Script
# This script creates a portable R AppImage for Linux distributions
# Supports both x86_64 and aarch64 architectures
# Includes official R logo, pre-configured repositories, and versioned user libraries

set -e

# Detect architecture
ARCH=$(uname -m)
case $ARCH in
    x86_64)
        ARCH_NAME="x86_64"
        ;;
    aarch64|arm64)
        ARCH_NAME="aarch64"
        ;;
    *)
        echo "ERROR: Unsupported architecture: $ARCH"
        echo "Supported: x86_64, aarch64"
        exit 1
        ;;
esac

# Configuration
R_VERSION="${R_VERSION:-4.5.1}"
APPIMAGE_NAME="R-${R_VERSION}-${ARCH_NAME}.AppImage"
BUILD_DIR="$(pwd)/build"
APPDIR="${BUILD_DIR}/R.AppDir"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check dependencies
check_dependencies() {
    log_info "Checking dependencies for ${ARCH_NAME}..."
    
    local deps=("wget" "gcc" "g++" "gfortran" "make" "curl" "file" "desktop-file-validate")
    local missing=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing+=("$dep")
        fi
    done
    
    if [ ${#missing[@]} -ne 0 ]; then
        log_error "Missing dependencies: ${missing[*]}"
        log_info "Please install them using your package manager:"
        log_info "  Ubuntu/Debian: make deps  (or: make deps-ubuntu)"
        log_info "  Fedora:        make deps  (or: make deps-fedora)"
        log_info "  CentOS/RHEL:   make deps  (or: make deps-centos)"
        log_info ""
        log_info "Or install manually:"
        log_info "  Ubuntu/Debian: sudo apt-get install build-essential gfortran curl wget file desktop-file-utils libx11-dev libxt-dev"
        log_info "  Fedora:        sudo dnf install gcc-gfortran curl wget file desktop-file-utils libX11-devel libXt-devel"
        log_info "  CentOS/RHEL:   sudo yum install gcc-gfortran curl wget file desktop-file-utils libX11-devel libXt-devel"
        exit 1
    fi
    
    log_success "All dependencies are available for ${ARCH_NAME}"
}

# Download appimagetool
download_appimagetool() {
    log_info "Downloading appimagetool for ${ARCH_NAME}..."
    
    if [ ! -f "${BUILD_DIR}/appimagetool" ]; then
        mkdir -p "${BUILD_DIR}"
        cd "${BUILD_DIR}"
        
        # Download architecture-specific appimagetool
        case $ARCH_NAME in
            x86_64)
                wget -O appimagetool "https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage"
                ;;
            aarch64)
                wget -O appimagetool "https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-aarch64.AppImage"
                ;;
        esac
        
        chmod +x appimagetool
        cd - > /dev/null
    fi
    
    log_success "appimagetool ready for ${ARCH_NAME}"
}

# Create AppDir structure
create_appdir_structure() {
    log_info "Creating AppDir structure for ${ARCH_NAME}..."
    
    rm -rf "${APPDIR}"
    mkdir -p "${APPDIR}"/{usr/bin,usr/lib,usr/share/applications,usr/share/icons/hicolor/256x256/apps}
    
    log_success "AppDir structure created"
}

# Build R from source
build_r() {
    log_info "Building R ${R_VERSION} from source for ${ARCH_NAME}..."
    
    cd "${BUILD_DIR}"
    
    # Download R source if not exists
    if [ ! -f "R-${R_VERSION}.tar.gz" ]; then
        log_info "Downloading R source code..."
        wget "https://cran.r-project.org/src/base/R-4/R-${R_VERSION}.tar.gz"
    fi
    
    # Extract and build
    if [ ! -d "R-${R_VERSION}" ]; then
        log_info "Extracting R source..."
        tar -xzf "R-${R_VERSION}.tar.gz"
    fi
    
    cd "R-${R_VERSION}"
    
    log_info "Configuring R build for ${ARCH_NAME}..."
    
    # Architecture-specific configuration
    local config_args="--prefix=${APPDIR}/usr \
        --enable-R-shlib \
        --enable-memory-profiling \
        --with-blas \
        --with-lapack \
        --with-readline \
        --with-cairo \
        --with-libpng \
        --with-jpeglib \
        --with-libtiff \
        --with-ICU \
        --with-x \
        --enable-java=no"
    
    # Add architecture-specific flags if needed
    case $ARCH_NAME in
        aarch64)
            # ARM64 specific optimizations
            export CFLAGS="${CFLAGS} -march=armv8-a -O2"
            export CXXFLAGS="${CXXFLAGS} -march=armv8-a -O2"
            export FFLAGS="${FFLAGS} -O2"
            ;;
        x86_64)
            # x86_64 specific optimizations
            export CFLAGS="${CFLAGS} -march=x86-64 -O2"
            export CXXFLAGS="${CXXFLAGS} -march=x86-64 -O2"
            export FFLAGS="${FFLAGS} -O2"
            ;;
    esac
    
    log_info "Configure command: ./configure $config_args"
    ./configure $config_args
    
    log_info "Compiling R (this may take a while - up to 3 hours on ARM64)..."
    local nproc_count=$(nproc)
    # Limit parallel jobs on ARM64 to prevent memory issues
    if [ "$ARCH_NAME" = "aarch64" ] && [ "$nproc_count" -gt 2 ]; then
        nproc_count=2
        log_info "Limiting to 2 parallel jobs on ARM64 to prevent memory issues"
    fi
    
    make -j${nproc_count}
    
    log_info "Installing R to AppDir..."
    make install
    
    cd - > /dev/null
    log_success "R built and installed to AppDir for ${ARCH_NAME}"
}

# Create R profile with default repositories
create_r_profile() {
    log_info "Creating R profile with default repositories..."
    
    local r_etc_dir="${APPDIR}/usr/lib/R/etc"
    local rprofile_site="${r_etc_dir}/Rprofile.site"
    
    # Ensure the etc directory exists
    mkdir -p "${r_etc_dir}"
    
    # Create Rprofile.site with repository configuration
    cat > "${rprofile_site}" << 'EOF'
# Rprofile.site for R AppImage
# This file is executed at R startup

# Set default repositories for package installation
local({
    r <- getOption("repos")
    r["CRAN"] <- "https://cloud.r-project.org"
    r["source"] <- "https://packagemanager.rstudio.com/all/latest"
    options(repos = r)
})

# Display AppImage startup message
if (interactive()) {
    cat("R AppImage - Portable R Environment\n")
    cat("Default repositories configured:\n")
    cat("  CRAN: https://cloud.r-project.org\n")
    cat("  Source: https://packagemanager.rstudio.com/all/latest\n\n")
}
EOF
    
    log_success "R profile created with default repositories"
}

# Copy required libraries
copy_libraries() {
    log_info "Copying required shared libraries for ${ARCH_NAME}..."
    
    # Create lib directories
    mkdir -p "${APPDIR}/usr/lib"
    
    # Find and copy shared libraries that R depends on
    log_info "Analyzing R dependencies..."
    
    # Get list of shared libraries R needs
    local r_binary="${APPDIR}/usr/bin/R"
    local r_lib="${APPDIR}/usr/lib/R/bin/exec/R"
    
    # Check both R wrapper and actual R binary
    local binaries=("$r_binary")
    if [ -f "$r_lib" ]; then
        binaries+=("$r_lib")
    fi
    
    local all_libs=()
    for binary in "${binaries[@]}"; do
        if [ -f "$binary" ]; then
            local libs=($(ldd "$binary" 2>/dev/null | grep "=>" | awk '{print $3}' | grep -v "^$" || true))
            all_libs+=("${libs[@]}")
        fi
    done
    
    # Remove duplicates
    local unique_libs=($(printf '%s\n' "${all_libs[@]}" | sort -u))
    
    # Copy essential libraries (skip system libraries that should be available everywhere)
    local skip_patterns="linux-vdso|ld-linux|libc\.|libm\.|libdl\.|librt\.|libpthread\.|libresolv\.|libnss_|libutil\.|libcrypt\.|libX11\.|libXt\.|libXext\.|libXmu\."
    
    for lib in "${unique_libs[@]}"; do
        if [[ -f "$lib" ]] && ! echo "$lib" | grep -E "$skip_patterns" > /dev/null; then
            local libname=$(basename "$lib")
            if [ ! -f "${APPDIR}/usr/lib/$libname" ]; then
                log_info "Copying $libname"
                cp "$lib" "${APPDIR}/usr/lib/"
            fi
        fi
    done
    
    # Also check for architecture-specific library paths
    case $ARCH_NAME in
        aarch64)
            local lib_paths=("/lib/aarch64-linux-gnu" "/usr/lib/aarch64-linux-gnu")
            ;;
        x86_64)
            local lib_paths=("/lib/x86_64-linux-gnu" "/usr/lib/x86_64-linux-gnu")
            ;;
    esac
    
    # Copy some commonly needed libraries from system paths
    for lib_path in "${lib_paths[@]}"; do
        if [ -d "$lib_path" ]; then
            for essential_lib in "libgfortran.so.*" "libquadmath.so.*" "libgomp.so.*"; do
                find "$lib_path" -name "$essential_lib" -exec cp {} "${APPDIR}/usr/lib/" \; 2>/dev/null || true
            done
        fi
    done
    
    log_success "Libraries copied for ${ARCH_NAME}"
}

# Create desktop file
create_desktop_file() {
    log_info "Creating desktop file..."
    
    cat > "${APPDIR}/usr/share/applications/R.desktop" << 'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=R
Comment=R Statistical Computing Environment
Exec=R
Icon=R
Categories=Science;Math;
Terminal=true
StartupNotify=true
EOF
    
    # Copy desktop file to AppDir root (required by appimagetool)
    cp "${APPDIR}/usr/share/applications/R.desktop" "${APPDIR}/R.desktop"
    
    # Validate desktop file
    if command -v desktop-file-validate >/dev/null 2>&1; then
        desktop-file-validate "${APPDIR}/usr/share/applications/R.desktop"
        log_success "Desktop file created and validated"
    else
        log_warning "desktop-file-validate not found, desktop file created but not validated"
    fi
}

# Download and create application icon
create_icon() {
    log_info "Downloading official R logo..."
    
    local icon_dir="${APPDIR}/usr/share/icons/hicolor/256x256/apps"
    local icon_path="${icon_dir}/R.png"
    local root_icon_path="${APPDIR}/R.png"
    
    # Ensure the icon directory exists
    mkdir -p "$icon_dir"
    
    # Download the official R logo
    cd "${BUILD_DIR}"
    if [ ! -f "Rlogo.svg" ]; then
        log_info "Downloading R logo from r-project.org..."
        if wget -O Rlogo.svg "https://www.r-project.org/logo/Rlogo.svg"; then
            log_success "R logo downloaded successfully"
        else
            log_error "Failed to download R logo"
            exit 1
        fi
    else
        log_info "R logo already downloaded"
    fi
    
    # Convert SVG to PNG
    if command -v convert >/dev/null 2>&1; then
        log_info "Converting SVG to PNG using ImageMagick..."
        if convert -background transparent "Rlogo.svg" -resize 256x256 "$icon_path"; then
            log_success "Icon converted to PNG"
        else
            log_error "Failed to convert SVG to PNG"
            exit 1
        fi
    elif command -v rsvg-convert >/dev/null 2>&1; then
        log_info "Converting SVG to PNG using rsvg-convert..."
        if rsvg-convert -w 256 -h 256 -f png "Rlogo.svg" -o "$icon_path"; then
            log_success "Icon converted to PNG"
        else
            log_error "Failed to convert SVG to PNG"
            exit 1
        fi
    elif command -v inkscape >/dev/null 2>&1; then
        log_info "Converting SVG to PNG using Inkscape..."
        if inkscape --export-type=png --export-filename="$icon_path" --export-width=256 --export-height=256 "Rlogo.svg"; then
            log_success "Icon converted to PNG"
        else
            log_error "Failed to convert SVG to PNG"
            exit 1
        fi
    else
        log_error "No SVG converter found. Please install one of: imagemagick, librsvg2-bin, or inkscape"
        log_info "Installing ImageMagick: sudo apt-get install imagemagick"
        log_info "Installing rsvg-convert: sudo apt-get install librsvg2-bin"
        log_info "Installing Inkscape: sudo apt-get install inkscape"
        exit 1
    fi
    
    # Verify the icon was created
    if [ ! -f "$icon_path" ]; then
        log_error "Icon file not found after conversion: $icon_path"
        exit 1
    fi
    
    # Copy icon to AppDir root (required by appimagetool)
    if cp "$icon_path" "$root_icon_path"; then
        log_success "Icon copied to AppDir root"
        log_info "Icon size: $(ls -lh "$root_icon_path" | awk '{print $5}')"
    else
        log_error "Failed to copy icon to AppDir root"
        exit 1
    fi
    
    cd - > /dev/null
}

# Create AppRun script
create_apprun() {
    log_info "Creating AppRun script..."
    
    cat > "${APPDIR}/AppRun" << EOF
#!/bin/bash

# AppRun script for R AppImage

# Get the directory where this script is located
HERE="\$(dirname "\$(readlink -f "\$0")")"

# Clear any existing R environment variables to avoid conflicts
unset R_HOME R_LIBS_USER R_SHARE_DIR R_INCLUDE_DIR R_DOC_DIR

# Set up environment for AppImage R
export PATH="\${HERE}/usr/bin:\${PATH}"
export LD_LIBRARY_PATH="\${HERE}/usr/lib:\${LD_LIBRARY_PATH}"
export R_HOME="\${HERE}/usr/lib/R"

# Set up user-writable library directory with AppImage and version info
R_USER_LIB_DIR="\${HOME}/.local/lib/R/AppImage/${R_VERSION}/library"
mkdir -p "\${R_USER_LIB_DIR}"
export R_LIBS_USER="\${R_USER_LIB_DIR}"

# Ensure R can find its resources
export R_SHARE_DIR="\${HERE}/usr/share/R/share"
export R_INCLUDE_DIR="\${HERE}/usr/share/R/include"
export R_DOC_DIR="\${HERE}/usr/share/R/doc"

# Set up additional R environment variables for package installation
export R_LIBS="\${R_USER_LIB_DIR}:\${HERE}/usr/lib/R/library"

# Launch R with any arguments passed
exec "\${HERE}/usr/bin/R" "\$@"
EOF
    
    chmod +x "${APPDIR}/AppRun"
    
    log_success "AppRun script created with versioned user library support"
}

# Create .DirIcon
create_diricon() {
    local root_icon_path="${APPDIR}/R.png"
    local diricon_path="${APPDIR}/.DirIcon"
    
    if [ -f "$root_icon_path" ]; then
        if cp "$root_icon_path" "$diricon_path"; then
            log_success "Created .DirIcon"
        else
            log_error "Failed to create .DirIcon"
            exit 1
        fi
    else
        log_error "Root icon not found at $root_icon_path"
        exit 1
    fi
}

# Build the AppImage
build_appimage() {
    log_info "Building AppImage for ${ARCH_NAME}..."
    
    cd "${BUILD_DIR}"
    
    # Clean up any existing AppImage
    rm -f "${APPIMAGE_NAME}"
    
    # Build the AppImage
    ARCH=${ARCH_NAME} ./appimagetool "${APPDIR}" "${APPIMAGE_NAME}"
    
    if [ -f "${APPIMAGE_NAME}" ]; then
        log_success "AppImage created: ${BUILD_DIR}/${APPIMAGE_NAME}"
        
        # Make it executable
        chmod +x "${APPIMAGE_NAME}"
        
        # Show file info
        log_info "AppImage details:"
        ls -lh "${APPIMAGE_NAME}"
        file "${APPIMAGE_NAME}"
        
        # Show size
        local size=$(du -h "${APPIMAGE_NAME}" | cut -f1)
        log_info "AppImage size: ${size}"
    else
        log_error "Failed to create AppImage"
        exit 1
    fi
}

# Test the AppImage
test_appimage() {
    log_info "Testing AppImage..."
    
    cd "${BUILD_DIR}"
    
    # Test if AppImage runs
    if ./"${APPIMAGE_NAME}" --version > /dev/null 2>&1; then
        log_success "AppImage test passed"
        local version_output=$(./"${APPIMAGE_NAME}" --version 2>&1 | head -1)
        log_info "R version: ${version_output}"
        log_info "You can run: ./${APPIMAGE_NAME}"
    else
        log_warning "AppImage test failed, but file was created"
        log_info "Try running manually: ./${APPIMAGE_NAME} --version"
    fi
}

# Show build summary
show_summary() {
    log_info ""
    log_info "======================================"
    log_success "R AppImage Build Summary"
    log_info "======================================"
    log_info "Architecture: ${ARCH_NAME}"
    log_info "R Version: ${R_VERSION}"
    log_info "AppImage: ${BUILD_DIR}/${APPIMAGE_NAME}"
    
    if [ -f "${BUILD_DIR}/${APPIMAGE_NAME}" ]; then
        local size=$(du -h "${BUILD_DIR}/${APPIMAGE_NAME}" | cut -f1)
        log_info "Size: ${size}"
    fi
    
    log_info ""
    log_info "Usage examples:"
    log_info "  Interactive R:     ./build/${APPIMAGE_NAME}"
    log_info "  Run script:        ./build/${APPIMAGE_NAME} script.R"
    log_info "  Batch mode:        ./build/${APPIMAGE_NAME} --slave -e \"print('Hello')\""
    log_info "  Install packages:  ./build/${APPIMAGE_NAME} -e \"install.packages('ggplot2')\""
    log_info ""
    log_info "Package management:"
    log_info "  User library:      ~/.local/lib/R/AppImage/${R_VERSION}/library"
    log_info "  Auto-configured repos: CRAN + RStudio Package Manager"
    log_info ""
    log_info "System integration:"
    log_info "  Install to PATH:   make install"
    log_info "  Desktop entry:     make desktop-integration"
    log_info "======================================"
}

# Main function
main() {
    log_info "Starting R AppImage build process..."
    log_info "Target Architecture: ${ARCH_NAME}"
    log_info "R Version: ${R_VERSION}"
    log_info "Build directory: ${BUILD_DIR}"
    log_info "Timestamp: $(date)"
    
    check_dependencies
    download_appimagetool
    create_appdir_structure
    build_r
    create_r_profile
    copy_libraries
    create_desktop_file
    create_icon
    create_apprun
    create_diricon
    build_appimage
    test_appimage
    show_summary
    
    log_success "R AppImage build completed for ${ARCH_NAME}!"
}

# Handle interrupts
trap 'log_error "Build interrupted"; exit 130' INT TERM

# Run main function
main "$@"