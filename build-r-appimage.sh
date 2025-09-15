#!/bin/bash

# R AppImage builder Script with Optional Pre-installed Packages
# This script creates a portable R AppImage for Linux distributions
# Supports both x86_64 and aarch64 architectures

set -e

# Command line options
BUILD_MODE="minimal"  # Default to minimal build
SKIP_PACKAGES=true    # Default to skipping packages

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --with-packages)
            BUILD_MODE="packages"
            SKIP_PACKAGES=false
            shift
            ;;
        --minimal)
            BUILD_MODE="minimal"
            SKIP_PACKAGES=true
            shift
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --minimal        Build minimal R AppImage (default)"
            echo "  --with-packages  Build with pre-installed packages (immutable)"
            echo "  --help          Show this help message"
            echo ""
            echo "Environment variables:"
            echo "  R_VERSION       R version to build (default: 4.5.1)"
            echo ""
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

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
if [ "$BUILD_MODE" = "packages" ]; then
    APPIMAGE_NAME="R-${R_VERSION}-${ARCH_NAME}-packages.AppImage"
else
    APPIMAGE_NAME="R-${R_VERSION}-${ARCH_NAME}.AppImage"
fi
BUILD_DIR="$(pwd)/build"
APPDIR="${BUILD_DIR}/R.AppDir"

# Pre-installed packages configuration (only used with --with-packages)
# Add or remove packages as needed
PREINSTALLED_PACKAGES=(
    "jsonlite"
    "httr"
    "ggplot2"
    "dplyr"
    "tidyr"
    "readr"
    "stringr"
    "lubridate"
    "shiny"
    "rmarkdown"
    "knitr"
    "devtools"
    "data.table"
    "plotly"
    "DT"
)

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
    
    # IMPORTANT: Use /usr as prefix, not ${APPDIR}/usr to avoid hardcoded paths
    # We'll use DESTDIR during make install to redirect to AppDir
    local config_args="--prefix=/usr \
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
    
    log_info "Installing R to AppDir using DESTDIR..."
    # Use DESTDIR to redirect installation to AppDir while keeping relative paths
    make install DESTDIR="${APPDIR}"
    
    cd - > /dev/null
    log_success "R built and installed to AppDir for ${ARCH_NAME}"
}

# Install R packages during build (only if not skipping packages)
install_r_packages() {
    if [ "$SKIP_PACKAGES" = true ]; then
        log_info "Skipping package installation (minimal build)"
        return 0
    fi
    
    log_info "Installing pre-configured R packages..."
    
    if [ ${#PREINSTALLED_PACKAGES[@]} -eq 0 ]; then
        log_info "No packages configured for installation"
        return 0
    fi
    
    local r_binary="${APPDIR}/usr/bin/R"
    local lib_dir="${APPDIR}/usr/lib/R/library"
    
    # Verify R is working
    if ! "$r_binary" --version > /dev/null 2>&1; then
        log_error "R binary not working. Cannot install packages."
        exit 1
    fi
    
    # Set up temporary environment for package installation
    export R_HOME="${APPDIR}/usr/lib/R"
    export LD_LIBRARY_PATH="${APPDIR}/usr/lib:${LD_LIBRARY_PATH}"
    export PATH="${APPDIR}/usr/bin:${PATH}"
    
    log_info "Installing ${#PREINSTALLED_PACKAGES[@]} packages..."
    
    # Create R script for package installation
    local install_script="${BUILD_DIR}/install_packages.R"
    cat > "$install_script" << EOF
# Set repositories
options(repos = c(
    CRAN = "https://cloud.r-project.org",
    source = "https://packagemanager.rstudio.com/all/latest"
))

# Set library path
.libPaths("${lib_dir}")

# Function to install a package with error handling
install_package_safe <- function(pkg) {
    cat("Installing package:", pkg, "\n")
    tryCatch({
        if (!require(pkg, character.only = TRUE, quietly = TRUE)) {
            install.packages(pkg, lib = "${lib_dir}", dependencies = TRUE, quiet = FALSE)
            if (require(pkg, character.only = TRUE, quietly = TRUE)) {
                cat("[OK] Successfully installed:", pkg, "\n")
                return(TRUE)
            } else {
                cat("[ERROR] Failed to load after installation:", pkg, "\n")
                return(FALSE)
            }
        } else {
            cat("[OK] Already available:", pkg, "\n")
            return(TRUE)
        }
    }, error = function(e) {
        cat("[ERROR] Error installing", pkg, ":", conditionMessage(e), "\n")
        return(FALSE)
    })
}

# Install packages
packages <- c($(printf '"%s",' "${PREINSTALLED_PACKAGES[@]}" | sed 's/,$//'))
results <- sapply(packages, install_package_safe)

# Summary
successful <- sum(results)
total <- length(packages)
cat("\nPackage installation summary:\n")
cat("Successfully installed:", successful, "out of", total, "packages\n")

if (successful < total) {
    failed_packages <- packages[!results]
    cat("Failed packages:", paste(failed_packages, collapse = ", "), "\n")
}

# List all installed packages
cat("\nAll installed packages:\n")
installed_pkgs <- installed.packages(lib.loc = "${lib_dir}")[, "Package"]
cat(paste(sort(installed_pkgs), collapse = ", "), "\n")

# Exit with error code if any packages failed
if (successful < total) {
    quit(status = 1)
} else {
    quit(status = 0)
}
EOF
    
    log_info "Running package installation script..."
    if "$r_binary" --slave < "$install_script"; then
        log_success "All packages installed successfully"
    else
        log_warning "Some packages failed to install, but continuing with build"
    fi
    
    # Clean up
    rm -f "$install_script"
    
    # Show final package count
    local pkg_count=$(find "${lib_dir}" -maxdepth 1 -type d | wc -l)
    log_info "Total packages in library: $((pkg_count - 1))" # Subtract 1 for the library dir itself
}

# Create R profile
create_r_profile() {
    log_info "Creating R profile..."
    
    local r_etc_dir="${APPDIR}/usr/lib/R/etc"
    local rprofile_site="${r_etc_dir}/Rprofile.site"
    
    # Ensure the etc directory exists
    mkdir -p "${r_etc_dir}"
    
        # Create list of pre-installed packages for display
        local packages_list=""
        for pkg in "${PREINSTALLED_PACKAGES[@]}"; do
            packages_list="$packages_list\"$pkg\", "
        done
        packages_list=${packages_list%, }  # Remove trailing comma and space
        
        # Create Rprofile.site with immutable configuration
        cat > "${rprofile_site}" << EOF
# Rprofile.site for R AppImage
# This file is executed at R startup

# Set default repositories (for reference only)
local({
    r <- getOption("repos")
    r["CRAN"] <- "https://cloud.r-project.org"
    r["source"] <- "https://packagemanager.rstudio.com/all/latest"
    options(repos = r)
})

# Pre-installed packages in this AppImage
.preinstalled_packages <- c($packages_list)

# Override install.packages to prevent installation
install.packages <- function(...) {
    cat("\\n")
    cat("═══════════════════════════════════════════════════════════\\n")
    cat("    This is an immutable R AppImage environment\\n")
    cat("═══════════════════════════════════════════════════════════\\n")
    cat("\\n")
    cat("Package installation is disabled to maintain consistency.\\n")
    cat("\\n")
    cat("Pre-installed packages:\\n")
    
    # Display packages in columns
    packages_per_row <- 3
    for (i in seq_along(.preinstalled_packages)) {
        cat(sprintf("  %-20s", .preinstalled_packages[i]))
        if (i %% packages_per_row == 0 || i == length(.preinstalled_packages)) {
            cat("\\n")
        }
    }
    
    cat("\\n")
    cat("To check if a package is available:\\n")
    cat("   > library(package_name)\\n")
    cat("   > require(package_name)\\n")
    cat("\\n")
    cat("Need different packages? Build a custom AppImage with:\\n")
    cat("   > Edit PREINSTALLED_PACKAGES in build script\\n")
    cat("   > Run: make appimage-packages\\n")
    cat("\\n")
    cat("═══════════════════════════════════════════════════════════\\n")
    cat("\\n")
}

# Override remove.packages to prevent removal
remove.packages <- function(...) {
    cat("\\n[ERROR] Package removal is disabled in this immutable environment.\\n\\n")
}

# Override update.packages to prevent updates
update.packages <- function(...) {
    cat("\\n[ERROR] Package updates are disabled in this immutable environment.\\n\\n")
}

# Helper function to show available packages
show.available.packages <- function() {
    cat("\\nPre-installed packages in this AppImage:\\n\\n")
    
    # Get actually installed packages
    installed <- installed.packages()[, "Package"]
    available_preinstalled <- intersect(.preinstalled_packages, installed)
    
    if (length(available_preinstalled) > 0) {
        packages_per_row <- 3
        for (i in seq_along(available_preinstalled)) {
            cat(sprintf("  %-20s", available_preinstalled[i]))
            if (i %% packages_per_row == 0 || i == length(available_preinstalled)) {
                cat("\\n")
            }
        }
    }
    
    cat("\\n")
    cat("Total:", length(available_preinstalled), "pre-installed packages\\n")
    cat("\\nUse library(package_name) to load a package.\\n\\n")
}

# Display AppImage startup message
if (interactive()) {
    cat("\\n")
    cat("R AppImage - Immutable Environment\\n")
    cat("════════════════════════════════════\\n")
    cat("R Version:", R.version.string, "\\n")
    cat("Architecture: ${ARCH_NAME}\\n")
    cat("Pre-installed packages:", length(.preinstalled_packages), "\\n")
    cat("\\n")
    cat("Type 'show.available.packages()' to see all packages\\n")
    cat("Package installation is disabled for consistency\\n")
    cat("\\n")
}
EOF

    log_success "R profile created for packages build"
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
Name=R (Immutable)
Comment=R Statistical Computing Environment - Pre-configured
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
    else
        log_error "Failed to copy icon to AppDir root"
        exit 1
    fi
    
    cd - > /dev/null
}

# Create AppRun script
create_apprun() {
    log_info "Creating AppRun script..."
    
    cat > "${APPDIR}/AppRun" << 'EOF'
#!/bin/bash

# AppRun script for R AppImage
# Get the directory where this script is located
HERE="$(dirname "$(readlink -f "$0")")"

# Clear any existing R environment variables to avoid conflicts and warnings
unset R_HOME R_LIBS_USER R_SHARE_DIR R_INCLUDE_DIR R_DOC_DIR R_LIBS R_ENVIRON R_PROFILE

# Set up environment for AppImage R
export PATH="${APPDIR}/usr/bin:${PATH}"
export LD_LIBRARY_PATH="${APPDIR}/usr/lib:${LD_LIBRARY_PATH}"

# Use only the built-in library (no user library for immutable environment)
export R_LIBS="${APPDIR}/usr/lib/R/library"

# Ensure R can find its resources
export R_SHARE_DIR="${APPDIR}/usr/share/R/share"
export R_INCLUDE_DIR="${APPDIR}/usr/share/R/include"
export R_DOC_DIR="${APPDIR}/usr/share/R/doc"

# Launch R with any arguments passed
exec "${HERE}/usr/bin/R" "$@"
EOF
    
    chmod +x "${APPDIR}/AppRun"
    
    log_success "AppRun script created"
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
    log_info "================================================================"
    log_success "R AppImage Build Summary"
    log_info "================================================================"
    log_info "Build Mode: ${BUILD_MODE}"
    log_info "Architecture: ${ARCH_NAME}"
    log_info "R Version: ${R_VERSION}"
    log_info "AppImage: ${BUILD_DIR}/${APPIMAGE_NAME}"
    
    if [ "$SKIP_PACKAGES" = false ]; then
        log_info "Pre-installed packages: ${#PREINSTALLED_PACKAGES[@]}"
    fi

    log_info "Package installation: Disabled (immutable)"

    
    if [ -f "${BUILD_DIR}/${APPIMAGE_NAME}" ]; then
        local size=$(du -h "${BUILD_DIR}/${APPIMAGE_NAME}" | cut -f1)
        log_info "Size: ${size}"
    fi
    
    if [ "$SKIP_PACKAGES" = false ]; then
        log_info ""
        log_info "[PACKAGES] Pre-installed packages:"
        printf '  %s\n' "${PREINSTALLED_PACKAGES[@]}" | sort
    fi
    
    log_info ""
    log_info "Usage examples:"
    log_info "  Interactive R:     ./${APPIMAGE_NAME}"
    log_info "  Run script:        ./${APPIMAGE_NAME} script.R"
    log_info "  Batch mode:        ./${APPIMAGE_NAME} --slave -e \"print('Hello')\""
    
    if [ "$SKIP_PACKAGES" = false ]; then
        log_info "  Show packages:     ./${APPIMAGE_NAME} -e \"show.available.packages()\""
    fi
    
    log_info ""
    log_info "System integration:"
    log_info "  Install to PATH:   make install"
    log_info "  Desktop entry:     make desktop-integration"
    log_info "================================================================"
}

# Main function
main() {
    log_info "Starting R AppImage build process..."
    log_info "Build Mode: ${BUILD_MODE}"
    log_info "Target Architecture: ${ARCH_NAME}"
    log_info "R Version: ${R_VERSION}"
    log_info "Build directory: ${BUILD_DIR}"
    
    if [ "$SKIP_PACKAGES" = false ]; then
        log_info "Pre-installing ${#PREINSTALLED_PACKAGES[@]} packages"
    else
        log_info "Building with base R packages only"
    fi
    
    log_info "Environment: Immutable (AppImage read-only filesystem)"
    
    log_info "Timestamp: $(date)"
    
    check_dependencies
    download_appimagetool
    create_appdir_structure
    build_r
    install_r_packages
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