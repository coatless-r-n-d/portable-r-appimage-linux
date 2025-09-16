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
    "httr2"
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

# Download linuxdeploy tool
download_linuxdeploy() {
    log_info "Downloading linuxdeploy for ${ARCH_NAME}..."
    
    if [ ! -f "${BUILD_DIR}/linuxdeploy" ]; then
        mkdir -p "${BUILD_DIR}"
        cd "${BUILD_DIR}"
        
        # Download architecture-specific linuxdeploy
        case $ARCH_NAME in
            x86_64)
                wget -O linuxdeploy "https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous/linuxdeploy-x86_64.AppImage"
                ;;
            aarch64)
                wget -O linuxdeploy "https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous/linuxdeploy-aarch64.AppImage"
                ;;
        esac
        
        chmod +x linuxdeploy
        cd - > /dev/null
    fi
    
    log_success "linuxdeploy ready for ${ARCH_NAME}"
}


# Create AppDir structure
create_appdir_structure() {
    log_info "Creating AppDir structure for ${ARCH_NAME}..."
    
    rm -rf "${APPDIR}"
    mkdir -p "${APPDIR}"/{usr/bin,usr/lib,usr/share/applications,usr/share/icons/hicolor/256x256/apps}
    
    log_success "AppDir structure created"
}

# Build R and install to temporary directory (not directly to AppDir)
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
    
    # Create installation directory (separate from AppDir)
    local install_dir="${BUILD_DIR}/R-install"
    rm -rf "$install_dir"
    mkdir -p "$install_dir"
    
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
    
    log_info "Compiling R (this may take a while - up to 20 minutes on ARM64)..."
    local nproc_count=$(nproc)
    # Limit parallel jobs on ARM64 to prevent memory issues
    if [ "$ARCH_NAME" = "aarch64" ] && [ "$nproc_count" -gt 2 ]; then
        nproc_count=2
        log_info "Limiting to 2 parallel jobs on ARM64 to prevent memory issues"
    fi
    
    make -j${nproc_count}
    
    log_info "Installing R to temporary directory..."
    # Use DESTDIR to redirect installation to install_dir while keeping relative paths
    make install DESTDIR="${install_dir}"
    
    cd - > /dev/null
    log_success "R built and installed for ${ARCH_NAME}"
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
    
    local install_dir="${BUILD_DIR}/R-install"
    local r_binary="${install_dir}/usr/bin/R"
    local lib_dir="${install_dir}/usr/lib/R/library"
    
    # [DEBUG] Check what we have as this goes wrong... (sometimes)
    log_info "Checking R installation..."
    log_info "R binary: $r_binary"
    log_info "R binary exists: $([ -f "$r_binary" ] && echo "YES" || echo "NO")"
    log_info "R binary executable: $([ -x "$r_binary" ] && echo "YES" || echo "NO")"
    
    if [ -f "$r_binary" ]; then
        log_info "R binary type: $(file "$r_binary")"
        if file "$r_binary" | grep -q "shell script"; then
            log_info "R binary is a shell script, checking first few lines:"
            head -5 "$r_binary" | sed 's/^/  /'
        fi
    fi
    
    # Set up comprehensive environment for package installation
    log_info "Setting up R environment for package installation..."
    
    # Clear any existing R environment that might interfere
    unset R_HOME R_LIBS_USER R_SHARE_DIR R_INCLUDE_DIR R_DOC_DIR R_LIBS R_ENVIRON R_PROFILE
    
    # Set up R environment pointing to our temporary installation
    export R_HOME="${install_dir}/usr/lib/R"
    export R_LIBS_SITE="${lib_dir}"
    export R_LIBS="${lib_dir}"
    export R_SHARE_DIR="${install_dir}/usr/share/R/share"
    export R_INCLUDE_DIR="${install_dir}/usr/share/R/include"
    export R_DOC_DIR="${install_dir}/usr/share/R/doc"
    
    # Set up library paths so R can find its own libraries
    local r_lib_path="${install_dir}/usr/lib/R/lib"
    if [ -d "$r_lib_path" ]; then
        export LD_LIBRARY_PATH="${r_lib_path}:${install_dir}/usr/lib:${LD_LIBRARY_PATH}"
    else
        export LD_LIBRARY_PATH="${install_dir}/usr/lib:${LD_LIBRARY_PATH}"
    fi
    
    # Add R to PATH
    export PATH="${install_dir}/usr/bin:${PATH}"
    
    # Verify R is working before proceeding
    log_info "Testing R binary..."
    if ! "$r_binary" --version > /dev/null 2>&1; then
        log_error "R binary test failed. Attempting to diagnose..."
        
        # Try to get more detailed error information
        log_info "Attempting to run R --version with error output:"
        "$r_binary" --version 2>&1 | sed 's/^/  ERROR: /' || true
        
        # Check if it's a library issue
        if command -v ldd >/dev/null 2>&1; then
            local actual_r_binary
            if [ -f "${install_dir}/usr/lib/R/bin/exec/R" ]; then
                actual_r_binary="${install_dir}/usr/lib/R/bin/exec/R"
                log_info "Checking dependencies of actual R binary: $actual_r_binary"
                ldd "$actual_r_binary" 2>&1 | sed 's/^/  /' || true
            fi
        fi
        
        log_error "Cannot proceed with package installation - R binary not functional"
        return 1
    fi
    
    log_success "R binary is working"
    
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
    # Do not remove the last newline as it may cause issues
    
    log_info "Running package installation script..."
    if "$r_binary" --slave < "$install_script"; then
        log_success "All packages installed successfully"
    else
        log_warning "Some packages failed to install, but continuing with build"
    fi
    
    # Clean up
    rm -f "$install_script"
    
    # Show final package count
    if [ -d "${lib_dir}" ]; then
        local pkg_count=$(find "${lib_dir}" -maxdepth 1 -type d | wc -l)
        log_info "Total packages in library: $((pkg_count - 1))" # Subtract 1 for the library dir itself
    fi
}

# Create R profile
create_r_profile() {
    log_info "Creating R profile..."
    
    local install_dir="${BUILD_DIR}/R-install"
    local r_etc_dir="${install_dir}/usr/lib/R/etc"
    local rprofile_site="${r_etc_dir}/Rprofile.site"
    
    # Ensure the etc directory exists
    mkdir -p "${r_etc_dir}"
    
    # Create different profiles based on build mode
    if [ "$SKIP_PACKAGES" = false ]; then
        # Packages build profile
        create_packages_profile "$rprofile_site"
    else
        # Minimal build profile
        create_minimal_profile "$rprofile_site"
    fi
    
    # Verify the file was created
    if [ -f "$rprofile_site" ]; then
        log_success "R profile created for ${BUILD_MODE} build: $rprofile_site"
    else
        log_error "Failed to create R profile file: $rprofile_site"
        exit 1
    fi
}

# Profile for minimal builds
create_minimal_profile() {
    local rprofile_site="$1"
    
    cat > "${rprofile_site}" << EOF
# Rprofile.site for R AppImage (Minimal Build)
# This file is executed at R startup

# Set default repositories
local({
    r <- getOption("repos")
    r["CRAN"] <- "https://cloud.r-project.org"
    r["source"] <- "https://packagemanager.rstudio.com/all/latest"
    options(repos = r)
})

# Override install.packages for minimal build
install.packages <- function(...) {
    cat("\\n")
    cat("═══════════════════════════════════════════════════════════\\n")
    cat("    R AppImage - Minimal Build Environment\\n")
    cat("═══════════════════════════════════════════════════════════\\n")
    cat("\\n")
    cat("This is a minimal R AppImage with base packages only.\\n")
    cat("Package installation is disabled (immutable filesystem).\\n")
    cat("\\n")
    cat("Available base packages:\\n")
    cat("  Base R packages: base, utils, stats, graphics, etc.\\n")
    cat("\\n")
    cat("To see all available packages:\\n")
    cat("   > library()\\n")
    cat("   > installed.packages()[,\"Package\"]\\n")
    cat("\\n")
    cat("Need additional packages?\\n")
    cat("   Build the packages version: make appimage-packages\\n")
    cat("   Or use a system R installation for package management\\n")
    cat("\\n")
    cat("═══════════════════════════════════════════════════════════\\n")
    cat("\\n")
}

# Override remove.packages and update.packages
remove.packages <- function(...) {
    cat("\\n[INFO] Package removal is disabled in this minimal AppImage environment.\\n\\n")
}

update.packages <- function(...) {
    cat("\\n[INFO] Package updates are disabled in this minimal AppImage environment.\\n\\n")
}

# Helper function to show available packages for minimal build
show.available.packages <- function() {
    cat("\\nR AppImage - Minimal Build\\n")
    cat("═══════════════════════════════\\n\\n")
    
    cat("This minimal build includes only base R packages.\\n\\n")
    
    # Show base packages
    base_pkgs <- installed.packages()[, "Package"]
    cat("Base R packages (", length(base_pkgs), " total):\\n")
    
    # Display in columns
    packages_per_row <- 4
    for (i in seq_along(base_pkgs)) {
        cat(sprintf("  %-15s", base_pkgs[i]))
        if (i %% packages_per_row == 0 || i == length(base_pkgs)) {
            cat("\\n")
        }
    }
    
    cat("\\n")
    cat("These packages are part of base R and always available.\\n")
    cat("Use library(package_name) to load any of these packages.\\n\\n")
    
    cat("For additional packages, consider:\\n")
    cat("  • Building the packages version: make appimage-packages\\n")
    cat("  • Using a system R installation with package management\\n\\n")
}

# Helper function to show build info
show.build.info <- function() {
    cat("\\nR AppImage Build Information\\n")
    cat("═══════════════════════════════\\n")
    cat("Build Type: Minimal (base packages only)\\n")
    cat("R Version:", R.version.string, "\\n")
    cat("Architecture: ${ARCH_NAME}\\n")
    cat("Filesystem: Immutable (read-only)\\n")
    cat("Package Installation: Disabled\\n\\n")
    
    cat("Use show.available.packages() to see what's included.\\n\\n")
}

# Display minimal build startup message
if (interactive()) {
    cat("\\n")
    cat("R AppImage - Minimal Build\\n")
    cat("═══════════════════════════════\\n")
    cat("R Version:", R.version.string, "\\n")
    cat("Architecture: ${ARCH_NAME}\\n")
    cat("Build: Base packages only\\n")
    cat("\\n")
    cat("Type 'show.available.packages()' to see available packages\\n")
    cat("Type 'show.build.info()' for build information\\n")
    cat("Package installation is disabled (immutable environment)\\n")
    cat("\\n")
}
EOF
}

# Profile for packages builds (existing functionality)
create_packages_profile() {
    local rprofile_site="$1"
    
    # Create list of pre-installed packages for display
    local packages_list=""
    for pkg in "${PREINSTALLED_PACKAGES[@]}"; do
        packages_list="$packages_list\"$pkg\", "
    done
    packages_list=${packages_list%, }  # Remove trailing comma and space
    
    cat > "${rprofile_site}" << EOF
# Rprofile.site for R AppImage (Packages Build)
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
    cat("    R AppImage - Packages Build Environment\\n")
    cat("═══════════════════════════════════════════════════════════\\n")
    cat("\\n")
    cat("Package installation is disabled (immutable filesystem).\\n")
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
    cat("\\nR AppImage - Packages Build\\n")
    cat("═══════════════════════════════\\n\\n")
    
    # Get actually installed packages
    installed <- installed.packages()[, "Package"]
    available_preinstalled <- intersect(.preinstalled_packages, installed)
    
    if (length(available_preinstalled) > 0) {
        cat("Pre-installed packages:\\n")
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
    cat("Plus base R packages for a complete environment.\\n\\n")
    cat("Use library(package_name) to load a package.\\n\\n")
}

# Helper function to show build info
show.build.info <- function() {
    cat("\\nR AppImage Build Information\\n")
    cat("═══════════════════════════════\\n")
    cat("Build Type: Packages (pre-configured)\\n")
    cat("R Version:", R.version.string, "\\n")
    cat("Architecture: ${ARCH_NAME}\\n")
    cat("Pre-installed packages:", length(.preinstalled_packages), "\\n")
    cat("Filesystem: Immutable (read-only)\\n")
    cat("Package Installation: Disabled\\n\\n")
    
    cat("Use show.available.packages() to see what's included.\\n\\n")
}

# Display AppImage startup message
if (interactive()) {
    cat("\\n")
    cat("R AppImage - Packages Build\\n")
    cat("════════════════════════════════\\n")
    cat("R Version:", R.version.string, "\\n")
    cat("Architecture: ${ARCH_NAME}\\n")
    cat("Pre-installed packages:", length(.preinstalled_packages), "\\n")
    cat("\\n")
    cat("Type 'show.available.packages()' to see all packages\\n")
    cat("Type 'show.build.info()' for build information\\n")
    cat("Package installation is disabled (immutable filesystem).\\n")
    cat("\\n")
}
EOF
}

# Use linuxdeploy to bundle everything into AppDir
bundle_with_linuxdeploy() {
    log_info "Using linuxdeploy to bundle R and dependencies..."
    
    cd "${BUILD_DIR}"
    
    local install_dir="${BUILD_DIR}/R-install"
    
    # Find the actual R binaries (not shell script wrappers)
    log_info "Locating R binaries..."
    
    # Check what type of files we have
    local r_wrapper="${install_dir}/usr/bin/R"
    local rscript_wrapper="${install_dir}/usr/bin/Rscript"
    local r_binary="${install_dir}/usr/lib/R/bin/exec/R"
    local rscript_binary="${install_dir}/usr/lib/R/bin/Rscript"
    
    # Check R's internal library directory
    local r_lib_dir="${install_dir}/usr/lib/R/lib"
    log_info "R library directory: $r_lib_dir"
    if [ -d "$r_lib_dir" ]; then
        log_info "R internal libraries found:"
        ls -la "$r_lib_dir" | sed 's/^/   /'
    fi
    
    # Determine which executables to deploy
    local executables_to_deploy=()
    local libraries_to_deploy=()
    
    # Use actual ELF binaries, not shell script wrappers
    if [ -f "$r_binary" ] && file "$r_binary" | grep -q "ELF"; then
        executables_to_deploy+=("$r_binary")
        log_info "Will deploy R binary: $r_binary"
    else
        log_warning "R binary not found or not ELF format: $r_binary"
    fi
    
    if [ -f "$rscript_binary" ] && file "$rscript_binary" | grep -q "ELF"; then
        executables_to_deploy+=("$rscript_binary")
        log_info "Will deploy Rscript binary: $rscript_binary"
    else
        log_warning "Rscript binary not found or not ELF format: $rscript_binary"
    fi
    
    # Find R-specific libraries that need to be bundled
    if [ -d "$r_lib_dir" ]; then
        for lib in "$r_lib_dir"/*.so*; do
            if [ -f "$lib" ]; then
                libraries_to_deploy+=("$lib")
                log_info "Found R library: $(basename "$lib")"
            fi
        done
    fi
    
    # Check for additional R binaries in lib/R/bin/
    local r_bin_dir="${install_dir}/usr/lib/R/bin"
    if [ -d "$r_bin_dir" ]; then
        for binary in "$r_bin_dir"/*; do
            if [ -f "$binary" ] && file "$binary" | grep -q "ELF" && [[ "$(basename "$binary")" != "R" ]] && [[ "$(basename "$binary")" != "Rscript" ]]; then
                executables_to_deploy+=("$binary")
                log_info "Found additional R binary: $binary"
            fi
        done
    fi
    
    if [ ${#executables_to_deploy[@]} -eq 0 ]; then
        log_error "No ELF binaries found to deploy!"
        exit 1
    fi
    
    # Set up environment for linuxdeploy to find R libraries
    log_info "Setting up library paths for linuxdeploy..."
    export LD_LIBRARY_PATH="${r_lib_dir}:${install_dir}/usr/lib:${LD_LIBRARY_PATH}"
    
    # Disable stripping to avoid newer ELF format warnings
    export DISABLE_COPYRIGHT_FILES_DEPLOYMENT=1
    export NO_STRIP=1
    
    # Run linuxdeploy to bundle everything
    log_info "Running linuxdeploy to create AppDir..."
    
    # Build linuxdeploy command with all executables and libraries
    # Note: Desktop file and icon are already created by dedicated functions
    local linuxdeploy_cmd="./linuxdeploy --appdir \"${APPDIR}\""
    
    # Add executables
    for exe in "${executables_to_deploy[@]}"; do
        linuxdeploy_cmd="$linuxdeploy_cmd --executable \"$exe\""
    done
    
    # Add R-specific libraries explicitly
    for lib in "${libraries_to_deploy[@]}"; do
        linuxdeploy_cmd="$linuxdeploy_cmd --library \"$lib\""
    done
    
    # Add desktop file and icon (created by dedicated functions)
    if [ -f "${APPDIR}/usr/share/applications/R.desktop" ]; then
        linuxdeploy_cmd="$linuxdeploy_cmd --desktop-file \"${APPDIR}/usr/share/applications/R.desktop\""
    fi
    
    if [ -f "${APPDIR}/usr/share/icons/hicolor/256x256/apps/R.png" ]; then
        linuxdeploy_cmd="$linuxdeploy_cmd --icon-file \"${APPDIR}/usr/share/icons/hicolor/256x256/apps/R.png\""
    fi
    
    log_info "Running: $linuxdeploy_cmd"
    
    # Run linuxdeploy and capture both stdout and stderr
    local linuxdeploy_output
    local linuxdeploy_exit_code
    
    if linuxdeploy_output=$(eval $linuxdeploy_cmd 2>&1); then
        linuxdeploy_exit_code=0
    else
        linuxdeploy_exit_code=$?
    fi
    
    # Display the output
    echo "$linuxdeploy_output"
    
    # Check if this was a real failure or just strip warnings
    local real_failure=false
    if [ $linuxdeploy_exit_code -ne 0 ]; then
        # Check if the failures are only strip-related
        if echo "$linuxdeploy_output" | grep -q "ERROR.*Strip call failed" && \
           echo "$linuxdeploy_output" | grep -q "unknown type.*section.*relr.dyn"; then
            log_warning "linuxdeploy completed with strip warnings (newer ELF format)"
            log_info "This is not a fatal error - libraries were deployed successfully"
        else
            real_failure=true
        fi
    fi
    
    if [ $linuxdeploy_exit_code -eq 0 ] || [ "$real_failure" = false ]; then
        log_success "linuxdeploy completed successfully"
    else
        log_warning "linuxdeploy approach failed"
        exit 1
    fi
    
    # Copy additional R resources that linuxdeploy doesn't handle
    log_info "Copying additional R resources..."
    
    # Copy the entire R installation structure
    if [ -d "${install_dir}/usr/lib/R" ]; then
        mkdir -p "${APPDIR}/usr/lib"
        cp -r "${install_dir}/usr/lib/R" "${APPDIR}/usr/lib/"
    fi

    local source_profile="${install_dir}/usr/lib/R/etc/Rprofile.site"
    if [ -f "$source_profile" ]; then
        mkdir -p "${APPDIR}/usr/lib/R/etc"
        cp "$source_profile" "${APPDIR}/usr/lib/R/etc/Rprofile.site"
        log_info "Explicitly copied R profile"
    fi
    
    # Copy R share directory
    if [ -d "${install_dir}/usr/share/R" ]; then
        mkdir -p "${APPDIR}/usr/share"
        cp -r "${install_dir}/usr/share/R" "${APPDIR}/usr/share/"
    fi
    
    # Copy the wrapper scripts to usr/bin (we need these for the AppRun)
    mkdir -p "${APPDIR}/usr/bin"
    if [ -f "$r_wrapper" ]; then
        cp "$r_wrapper" "${APPDIR}/usr/bin/"
        chmod +x "${APPDIR}/usr/bin/R"
    fi
    
    if [ -f "$rscript_wrapper" ]; then
        cp "$rscript_wrapper" "${APPDIR}/usr/bin/"
        chmod +x "${APPDIR}/usr/bin/Rscript"
    fi
    
    # Copy additional shared files
    if [ -d "${install_dir}/usr/share/man" ]; then
        mkdir -p "${APPDIR}/usr/share"
        cp -r "${install_dir}/usr/share/man" "${APPDIR}/usr/share/"
    fi
    
    log_success "linuxdeploy bundling completed"
}


create_desktop_file() {
    log_info "Creating desktop file..."
    
    # Create desktop file with proper AppImage naming
    cat > "${APPDIR}/usr/share/applications/Rappimage.desktop" << 'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=R (Immutable)
Comment=R Statistical Computing Environment - Pre-configured
Exec=R.AppImage
Icon=R
Categories=Science;Math;
Terminal=true
StartupNotify=true
EOF
    
    # Copy desktop file to AppDir root (required by appimagetool)
    cp "${APPDIR}/usr/share/applications/Rappimage.desktop" "${APPDIR}/Rappimage.desktop"
    
    # Validate desktop file
    if command -v desktop-file-validate >/dev/null 2>&1; then
        desktop-file-validate "${APPDIR}/usr/share/applications/Rappimage.desktop"
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
    if command -v magick >/dev/null 2>&1; then
        log_info "Converting SVG to PNG using ImageMagick..."
        if magick -background transparent "Rlogo.svg" -resize 256x256 "$icon_path"; then
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


create_appdata_file() {
    log_info "Creating AppData metadata file..."
    
    # Create metainfo directory
    local metainfo_dir="${APPDIR}/usr/share/metainfo"
    mkdir -p "${metainfo_dir}"
    
    # Determine build type description
    local build_description=""
    local package_info=""
    if [ "$SKIP_PACKAGES" = false ]; then
        build_description="with pre-installed packages"
        package_info="<li>Pre-installed packages: $(printf '%s, ' "${PREINSTALLED_PACKAGES[@]}" | sed 's/, $//')</li>"
    else
        build_description="minimal base installation"
        package_info="<li>Base R packages only</li>"
    fi
    
    # Create AppData XML file with proper AppImage naming
    cat > "${metainfo_dir}/org.rappimage.Rappimage.appdata.xml" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<component type="desktop-application">
    <id>org.rappimage.Rappimage</id>
    <metadata_license>MIT</metadata_license>
    <project_license>GPL-2.0-or-later</project_license>
    <name>AppImage for R Statistical Computing</name>
    <summary>R language for statistical computing and graphics in a Portable AppImage</summary>
    <description>
        <p>
            R is a free software environment for statistical computing and graphics. 
            This AppImage provides a portable, self-contained R installation that runs 
            on any Linux distribution without requiring system-wide installation.
        </p>
        <p>
            This immutable AppImage environment includes R ${R_VERSION} for ${ARCH_NAME} 
            architecture ${build_description}. The filesystem is read-only, ensuring 
            consistency across different systems and preventing package installation conflicts.
        </p>
        <ul>
            <li>Complete R statistical computing environment</li>
            <li>Self-contained - no system dependencies</li>
            <li>Portable across Linux distributions</li>
            <li>Immutable filesystem for consistency</li>
            ${package_info}
        </ul>
    </description>
    <launchable type="desktop-id">Rappimage.desktop</launchable>
    <icon type="stock">R</icon>
    <url type="homepage">https://www.r-project.org</url>
    <url type="help">https://cran.r-project.org/manuals.html</url>
    <url type="faq">https://cran.r-project.org/faqs.html</url>
    <developer id="org.rappimage.rappimage">
        <name>R AppImage Team</name>
    </developer>
    <categories>
        <category>Science</category>
        <category>Math</category>
        <category>Education</category>
        <category>Development</category>
    </categories>
    <keywords>
        <keyword>statistics</keyword>
        <keyword>data analysis</keyword>
        <keyword>graphics</keyword>
        <keyword>programming</keyword>
        <keyword>mathematics</keyword>
        <keyword>science</keyword>
        <keyword>research</keyword>
    </keywords>
    <provides>
        <binary>R</binary>
        <binary>Rscript</binary>
    </provides>
    <releases>
        <release version="${R_VERSION}" date="$(date +%Y-%m-%d)">
            <description>
                <p>R ${R_VERSION} packaged as portable AppImage</p>
                <ul>
                    <li>Immutable filesystem environment</li>
                    <li>Self-contained dependencies</li>
                    <li>Cross-distribution compatibility</li>
                    <li>Architecture: ${ARCH_NAME}</li>
                </ul>
            </description>
        </release>
    </releases>
    <content_rating type="oars-1.1" />
</component>
EOF

    # Validate the AppData file if appstream-util is available
    if command -v appstream-util >/dev/null 2>&1; then
        if appstream-util validate-relax "${metainfo_dir}/org.rappimage.Rappimage.appdata.xml"; then
            log_success "AppData file created and validated"
        else
            log_warning "AppData file created but validation failed"
        fi
    else
        log_success "AppData file created (install appstream-util for validation)"
    fi
}

# Create .DirIcon
create_diricon() {
    log_info "Creating .DirIcon..."
    
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
export PATH="${HERE}/usr/bin:${PATH}"
export LD_LIBRARY_PATH="${HERE}/usr/lib:${LD_LIBRARY_PATH}"
# Use only the built-in library (no user library for immutable environment)
export R_LIBS="${HERE}/usr/lib/R/library"

# Ensure R can find its resources
export R_SHARE_DIR="${HERE}/usr/share/R/share"
export R_INCLUDE_DIR="${HERE}/usr/share/R/include"
export R_DOC_DIR="${HERE}/usr/share/R/doc"
export R_PROFILE="${HERE}/usr/lib/R/etc/Rprofile.site"

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
    log_info "  Interactive R:     ./build/${APPIMAGE_NAME}"
    log_info "  Run script:        ./build/${APPIMAGE_NAME} script.R"
    log_info "  Batch mode:        ./build/${APPIMAGE_NAME} --slave -e \"print('Hello')\""
    
    if [ "$SKIP_PACKAGES" = false ]; then
        log_info "  Show packages:     ./build/${APPIMAGE_NAME} -e \"show.available.packages()\""
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
    
    check_dependencies      # Check for required tools
    download_appimagetool   # Download appimagetool
    download_linuxdeploy    # Download linuxdeploy
    create_appdir_structure # Create AppDir structure
    build_r                 # Build and install R
    install_r_packages      # Install R packages if not skipped
    create_r_profile        # Create Rprofile.site based on build mode
    bundle_with_linuxdeploy # Use linuxdeploy to bundle R and dependencies
    create_desktop_file     # Create desktop file in AppDir
    create_icon             # Download and create icon
    create_appdata_file     # Create AppData metadata
    create_diricon          # Create .DirIconf
    create_apprun           # Custom AppRun after linuxdeploy
    build_appimage          # Build the final AppImage
    test_appimage           # Test the AppImage
    show_summary            # Show build summary

    log_success "R AppImage build completed for ${ARCH_NAME}!"
}

# Handle interrupts
trap 'log_error "Build interrupted"; exit 130' INT TERM

# Run main function
main "$@"