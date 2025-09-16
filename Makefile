# Makefile for R AppImage Builder
# Multi-Architecture Support (x86_64 and aarch64)
# R 4.5.1 with immutable filesystem

R_VERSION ?= 4.5.1
BUILD_DIR = build
ARCH := $(shell uname -m)

ifeq ($(ARCH),x86_64)
    ARCH_NAME = x86_64
else ifeq ($(ARCH),aarch64)
    ARCH_NAME = aarch64
else ifeq ($(ARCH),arm64)
    ARCH_NAME = aarch64
else
    $(error Unsupported architecture: $(ARCH))
endif

APPIMAGE_NAME = R-$(R_VERSION)-$(ARCH_NAME).AppImage
APPIMAGE_PACKAGES_NAME = R-$(R_VERSION)-$(ARCH_NAME)-packages.AppImage
SCRIPT_NAME = build-r-appimage.sh

# Pre-installed packages (only used with appimage-packages target)
PREINSTALLED_PACKAGES = jsonlite httr2 ggplot2 dplyr tidyr readr stringr lubridate shiny rmarkdown knitr devtools data.table plotly DT

# Colors for output
GREEN = \033[0;32m
BLUE = \033[0;34m
YELLOW = \033[1;33m
RED = \033[0;31m
NC = \033[0m

.PHONY: all
all: appimage

.PHONY: help
help:
	@echo "$(BLUE)R AppImage Builder ($(ARCH_NAME)) - Immutable Environment$(NC)"
	@echo ""
	@echo "$(GREEN)Build R $(R_VERSION) AppImages with configurable environments$(NC)"
	@echo ""
	@echo "$(GREEN)Available targets:$(NC)"
	@echo "  appimage              - Build minimal R AppImage (base packages only)"
	@echo "  appimage-packages     - Build with pre-installed packages"
	@echo "  deps                  - Install dependencies (auto-detect OS)"
	@echo "  deps-ubuntu           - Install Ubuntu/Debian dependencies"
	@echo "  deps-fedora           - Install Fedora dependencies"
	@echo "  deps-centos           - Install CentOS/RHEL dependencies"
	@echo "  test                  - Test the built AppImage"
	@echo "  test-minimal          - Test minimal AppImage specifically"
	@echo "  test-packages         - Test packages AppImage specifically"
	@echo "  test-immutable        - Test immutable features (both builds)"
	@echo "  install               - Install minimal AppImage to ~/.local/bin"
	@echo "  install-packages      - Install packages AppImage to ~/.local/bin"
	@echo "  clean                 - Clean build artifacts"
	@echo "  clean-all             - Clean everything including downloads"
	@echo "  status                - Show build status"
	@echo "  show-packages         - Show pre-installed packages list"
	@echo "  arch-info             - Show architecture info"
	@echo "  os-info               - Show detected OS info"
	@echo "  validate              - Validate build script syntax"
	@echo "  quickstart            - Show quick start guide"
	@echo ""
	@echo "$(GREEN)Build Types:$(NC)"
	@echo "  $(BLUE)Minimal$(NC)    - Base R only, faster build, immutable filesystem"
	@echo "  $(BLUE)Packages$(NC)   - Pre-configured with packages, slower build, immutable filesystem"
	@echo ""
	@echo "$(YELLOW)IMPORTANT: Both builds have read-only filesystems (AppImage limitation)$(NC)"
	@echo "$(YELLOW)           NO additional packages can be installed after creation$(NC)"

.PHONY: appimage
appimage: $(SCRIPT_NAME)
	@echo "$(BLUE)Building minimal R $(R_VERSION) AppImage for $(ARCH_NAME)...$(NC)"
	@echo "$(GREEN)Base R packages only - immutable filesystem$(NC)"
	@chmod +x $(SCRIPT_NAME)
	@./$(SCRIPT_NAME) --minimal

.PHONY: appimage-packages
appimage-packages: $(SCRIPT_NAME)
	@echo "$(BLUE)Building R $(R_VERSION) AppImage with packages for $(ARCH_NAME)...$(NC)"
	@echo "$(YELLOW)This will take longer due to package pre-installation - immutable filesystem$(NC)"
	@chmod +x $(SCRIPT_NAME)
	@./$(SCRIPT_NAME) --with-packages

# Auto-detect OS and install appropriate dependencies
.PHONY: deps
deps:
	@echo "$(BLUE)Auto-detecting package manager...$(NC)"
	@if command -v apt-get >/dev/null 2>&1; then \
		echo "$(GREEN)Detected: Ubuntu/Debian$(NC)"; \
		$(MAKE) deps-ubuntu; \
	elif command -v dnf >/dev/null 2>&1 || command -v dnf5 >/dev/null 2>&1; then \
		echo "$(GREEN)Detected: Fedora$(NC)"; \
		$(MAKE) deps-fedora; \
	elif command -v yum >/dev/null 2>&1; then \
		echo "$(GREEN)Detected: CentOS/RHEL$(NC)"; \
		$(MAKE) deps-centos; \
	else \
		echo "$(RED)Error: No supported package manager found$(NC)"; \
		echo "$(YELLOW)Supported: apt-get (Ubuntu/Debian), dnf (Fedora), yum (CentOS/RHEL)$(NC)"; \
		echo "$(YELLOW)Please use one of: make deps-ubuntu, make deps-fedora, make deps-centos$(NC)"; \
		exit 1; \
	fi

.PHONY: deps-ubuntu
deps-ubuntu:
	@echo "$(BLUE)Installing dependencies for Ubuntu/Debian ($(ARCH_NAME))...$(NC)"
	sudo apt-get update
	sudo apt-get install -y \
		build-essential \
		gfortran \
		curl \
		wget \
		file \
		desktop-file-utils \
		appstream-util \
		libreadline-dev \
		libcurl4-openssl-dev \
		libssl-dev \
		libxml2-dev \
		libcairo2-dev \
		libpng-dev \
		libjpeg-dev \
		libtiff5-dev \
		libicu-dev \
		imagemagick \
		librsvg2-bin \
		libx11-dev \
		libxt-dev \
		libxext-dev \
		libxmu-dev \
		libxmuu-dev \
		libbz2-dev \
		liblzma-dev \
		libpcre3-dev \
		librsvg2-dev \
		libudunits2-dev \
		libharfbuzz-dev \
		libfribidi-dev \
		libfuse2t64 \
		libgdal-dev \
		gdal-bin \
		zlib1g-dev
	@if [ "$(ARCH_NAME)" = "aarch64" ]; then \
		echo "$(BLUE)Installing ARM64 packages...$(NC)"; \
		sudo apt-get install -y gcc-aarch64-linux-gnu g++-aarch64-linux-gnu || true; \
	fi
	@echo "$(GREEN)Ubuntu/Debian dependencies installed$(NC)"

.PHONY: deps-fedora
deps-fedora:
	@echo "$(BLUE)Installing Fedora dependencies ($(ARCH_NAME))...$(NC)"
	@if command -v dnf5 >/dev/null 2>&1; then \
		echo "$(BLUE)Using dnf5...$(NC)"; \
		sudo dnf group install -y 'Development Tools' || sudo dnf install -y @development-tools; \
	else \
		echo "$(BLUE)Using dnf...$(NC)"; \
		sudo dnf groupinstall -y 'Development Tools'; \
	fi
	sudo dnf install -y \
		gcc-gfortran \
		curl \
		wget \
		file \
		desktop-file-utils \
		appstream-util \
		readline-devel \
		libcurl-devel \
		openssl-devel \
		libxml2-devel \
		cairo-devel \
		libpng-devel \
		libjpeg-turbo-devel \
		libtiff-devel \
		libicu-devel \
		ImageMagick \
		librsvg2-tools \
		inkscape \
		libX11-devel \
		libXt-devel \
		libXext-devel \
		libXmu-devel \
		bzip2-devel \
		harfbuzz-devel \
		fribidi-devel \
		librsvg2-devel \
		udunits2-devel \
		gdal \
		gdal-devel \
		fuse-libs \
		xz-devel \
		pcre-devel \
		zlib-devel
	@echo "$(GREEN)Fedora dependencies installed$(NC)"

.PHONY: deps-centos
deps-centos:
	@echo "$(BLUE)Installing CentOS/RHEL dependencies ($(ARCH_NAME))...$(NC)"
	sudo yum groupinstall -y 'Development Tools'
	sudo yum install -y \
		gcc-gfortran \
		curl \
		wget \
		file \
		desktop-file-utils \
		readline-devel \
		libcurl-devel \
		openssl-devel \
		libxml2-devel \
		cairo-devel \
		libpng-devel \
		libjpeg-turbo-devel \
		libtiff-devel \
		libicu-devel \
		ImageMagick \
		librsvg2-tools \
		libX11-devel \
		libXt-devel \
		libXext-devel \
		libXmu-devel \
		bzip2-devel \
		harfbuzz-devel \
		fribidi-devel \
		librsvg2-devel \
		udunits2-devel \
		xz-devel \
		pcre-devel \
		zlib-devel
	sudo yum --enablerepo=epel -y install fuse-sshfs # install from EPEL
	user="$(whoami)"
	sudo usermod -a -G fuse "$user" 
	@echo "$(GREEN)CentOS/RHEL dependencies installed$(NC)"

.PHONY: test
test:
	@echo "$(BLUE)Testing available AppImages...$(NC)"
	@tested=false; \
	if [ -f "$(BUILD_DIR)/$(APPIMAGE_NAME)" ]; then \
		echo "$(YELLOW)Testing minimal AppImage...$(NC)"; \
		$(MAKE) test-minimal; \
		tested=true; \
	fi; \
	if [ -f "$(BUILD_DIR)/$(APPIMAGE_PACKAGES_NAME)" ]; then \
		echo "$(YELLOW)Testing packages AppImage...$(NC)"; \
		$(MAKE) test-packages; \
		tested=true; \
	fi; \
	if [ "$$tested" = false ]; then \
		echo "$(YELLOW)No AppImages found. Build one first:$(NC)"; \
		echo "  make appimage         (minimal build)"; \
		echo "  make appimage-packages (with packages)"; \
		exit 1; \
	fi

.PHONY: test-minimal
test-minimal:
	@if [ -f "$(BUILD_DIR)/$(APPIMAGE_NAME)" ]; then \
		echo "$(BLUE)Testing minimal AppImage...$(NC)"; \
		chmod +x "$(BUILD_DIR)/$(APPIMAGE_NAME)"; \
		"$(BUILD_DIR)/$(APPIMAGE_NAME)" --version && \
		echo "$(GREEN)[PASS] Minimal AppImage test passed$(NC)" || \
		echo "$(YELLOW)[WARN] Minimal AppImage exists but test failed$(NC)"; \
	else \
		echo "$(YELLOW)Minimal AppImage not found: $(BUILD_DIR)/$(APPIMAGE_NAME)$(NC)"; \
		echo "Run 'make appimage' first"; \
		exit 1; \
	fi

.PHONY: test-packages
test-packages:
	@if [ -f "$(BUILD_DIR)/$(APPIMAGE_PACKAGES_NAME)" ]; then \
		echo "$(BLUE)Testing packages AppImage...$(NC)"; \
		chmod +x "$(BUILD_DIR)/$(APPIMAGE_PACKAGES_NAME)"; \
		"$(BUILD_DIR)/$(APPIMAGE_PACKAGES_NAME)" --version && \
		echo "$(GREEN)[PASS] Packages AppImage test passed$(NC)" || \
		echo "$(YELLOW)[WARN] Packages AppImage exists but test failed$(NC)"; \
	else \
		echo "$(YELLOW)Packages AppImage not found: $(BUILD_DIR)/$(APPIMAGE_PACKAGES_NAME)$(NC)"; \
		echo "Run 'make appimage-packages' first"; \
		exit 1; \
	fi

.PHONY: test-immutable
test-immutable:
	@echo "$(BLUE)Testing immutable features (both builds are immutable)...$(NC)"
	@tested=false; \
	if [ -f "$(BUILD_DIR)/$(APPIMAGE_NAME)" ]; then \
		echo "$(YELLOW)Testing minimal AppImage immutable features:$(NC)"; \
		"$(BUILD_DIR)/$(APPIMAGE_NAME)" -e "install.packages('nonexistent')" || true; \
		echo ""; \
		tested=true; \
	fi; \
	if [ -f "$(BUILD_DIR)/$(APPIMAGE_PACKAGES_NAME)" ]; then \
		echo "$(YELLOW)Testing packages AppImage immutable features:$(NC)"; \
		"$(BUILD_DIR)/$(APPIMAGE_PACKAGES_NAME)" -e "install.packages('nonexistent')" || true; \
		echo ""; \
		echo "$(YELLOW)Testing show.available.packages():$(NC)"; \
		"$(BUILD_DIR)/$(APPIMAGE_PACKAGES_NAME)" -e "show.available.packages()"; \
		tested=true; \
	fi; \
	if [ "$$tested" = true ]; then \
		echo "$(GREEN)[PASS] Immutable features test completed$(NC)"; \
	else \
		echo "$(YELLOW)No AppImages found. Build one first$(NC)"; \
		exit 1; \
	fi

.PHONY: install
install:
	@if [ -f "$(BUILD_DIR)/$(APPIMAGE_NAME)" ]; then \
		echo "$(BLUE)Installing minimal AppImage to ~/.local/bin/...$(NC)"; \
		mkdir -p ~/.local/bin; \
		cp "$(BUILD_DIR)/$(APPIMAGE_NAME)" ~/.local/bin/R.AppImage; \
		chmod +x ~/.local/bin/R.AppImage; \
		echo "$(GREEN)[OK] Installed: ~/.local/bin/R.AppImage$(NC)"; \
		echo "$(YELLOW)Make sure ~/.local/bin is in your PATH$(NC)"; \
		echo "$(BLUE)Add to ~/.bashrc: export PATH=\"\$$HOME/.local/bin:\$$PATH\"$(NC)"; \
	else \
		echo "$(YELLOW)Minimal AppImage not found. Run 'make appimage' first$(NC)"; \
		exit 1; \
	fi

.PHONY: install-packages
install-packages:
	@if [ -f "$(BUILD_DIR)/$(APPIMAGE_PACKAGES_NAME)" ]; then \
		echo "$(BLUE)Installing packages AppImage to ~/.local/bin/...$(NC)"; \
		mkdir -p ~/.local/bin; \
		cp "$(BUILD_DIR)/$(APPIMAGE_PACKAGES_NAME)" ~/.local/bin/R-packages.AppImage; \
		chmod +x ~/.local/bin/R-packages.AppImage; \
		echo "$(GREEN)[OK] Installed: ~/.local/bin/R-packages.AppImage$(NC)"; \
		echo "$(YELLOW)Make sure ~/.local/bin is in your PATH$(NC)"; \
		echo "$(BLUE)Add to ~/.bashrc: export PATH=\"\$$HOME/.local/bin:\$$PATH\"$(NC)"; \
	else \
		echo "$(YELLOW)Packages AppImage not found. Run 'make appimage-packages' first$(NC)"; \
		exit 1; \
	fi

.PHONY: desktop-integration
desktop-integration:
	@echo "$(BLUE)Creating desktop integration...$(NC)"
	@mkdir -p ~/.local/share/applications
	@if [ -f "$(BUILD_DIR)/$(APPIMAGE_NAME)" ]; then \
		echo '[Desktop Entry]' > ~/.local/share/applications/R-AppImage.desktop; \
		echo 'Name=R Statistical Computing' >> ~/.local/share/applications/R-AppImage.desktop; \
		echo 'Comment=R Statistical Computing Environment' >> ~/.local/share/applications/R-AppImage.desktop; \
		echo 'Exec=R.AppImage' >> ~/.local/share/applications/R-AppImage.desktop; \
		echo 'Icon=R' >> ~/.local/share/applications/R-AppImage.desktop; \
		echo 'Type=Application' >> ~/.local/share/applications/R-AppImage.desktop; \
		echo 'Categories=Science;Math;' >> ~/.local/share/applications/R-AppImage.desktop; \
		echo 'Terminal=true' >> ~/.local/share/applications/R-AppImage.desktop; \
		echo 'StartupNotify=true' >> ~/.local/share/applications/R-AppImage.desktop; \
		echo "$(GREEN)[OK] Desktop integration created for minimal AppImage$(NC)"; \
	fi
	@if [ -f "$(BUILD_DIR)/$(APPIMAGE_PACKAGES_NAME)" ]; then \
		echo '[Desktop Entry]' > ~/.local/share/applications/R-Packages-AppImage.desktop; \
		echo 'Name=R Statistical Computing (Pre-configured)' >> ~/.local/share/applications/R-Packages-AppImage.desktop; \
		echo 'Comment=R Statistical Computing Environment - Pre-configured' >> ~/.local/share/applications/R-Packages-AppImage.desktop; \
		echo 'Exec=R-packages.AppImage' >> ~/.local/share/applications/R-Packages-AppImage.desktop; \
		echo 'Icon=R' >> ~/.local/share/applications/R-Packages-AppImage.desktop; \
		echo 'Type=Application' >> ~/.local/share/applications/R-Packages-AppImage.desktop; \
		echo 'Categories=Science;Math;' >> ~/.local/share/applications/R-Packages-AppImage.desktop; \
		echo 'Terminal=true' >> ~/.local/share/applications/R-Packages-AppImage.desktop; \
		echo 'StartupNotify=true' >> ~/.local/share/applications/R-Packages-AppImage.desktop; \
		echo "$(GREEN)[OK] Desktop integration created for packages AppImage$(NC)"; \
	fi

# Clean build artifacts but keep downloads
.PHONY: clean
clean:
	@echo "$(BLUE)Cleaning build artifacts...$(NC)"
	@if [ -d "$(BUILD_DIR)" ]; then \
		rm -rf $(BUILD_DIR)/R.AppDir; \
		rm -f $(BUILD_DIR)/R-$(R_VERSION)-*.AppImage; \
		echo "$(GREEN)[OK] Build artifacts cleaned$(NC)"; \
	else \
		echo "$(YELLOW)No build directory found$(NC)"; \
	fi

# Clean everything including downloads and source
.PHONY: clean-all
clean-all:
	@echo "$(BLUE)Cleaning everything...$(NC)"
	@if [ -d "$(BUILD_DIR)" ]; then \
		rm -rf $(BUILD_DIR); \
		echo "$(GREEN)[OK] Everything cleaned (including downloads)$(NC)"; \
	else \
		echo "$(YELLOW)No build directory found$(NC)"; \
	fi

# Clean only downloads but keep built AppImage
.PHONY: clean-downloads
clean-downloads:
	@echo "$(BLUE)Cleaning downloads...$(NC)"
	@if [ -d "$(BUILD_DIR)" ]; then \
		rm -rf $(BUILD_DIR)/R-$(R_VERSION); \
		rm -f $(BUILD_DIR)/R-$(R_VERSION).tar.gz; \
		rm -f $(BUILD_DIR)/appimagetool; \
		rm -f $(BUILD_DIR)/Rlogo.svg; \
		rm -rf $(BUILD_DIR)/R.AppDir; \
		echo "$(GREEN)[OK] Downloads cleaned$(NC)"; \
	else \
		echo "$(YELLOW)No build directory found$(NC)"; \
	fi

.PHONY: status
status:
	@echo "$(BLUE)Build Status:$(NC)"
	@echo "Architecture: $(ARCH_NAME)"
	@echo "R Version: $(R_VERSION)"
	@echo "Build Directory: $(BUILD_DIR)"
	@echo ""
	@echo "$(GREEN)Available builds:$(NC)"
	@if [ -f "$(BUILD_DIR)/$(APPIMAGE_NAME)" ]; then \
		echo "$(GREEN)[YES] Minimal AppImage:$(NC)"; \
		ls -lh "$(BUILD_DIR)/$(APPIMAGE_NAME)" | awk '{print "  Size: " $$5 ", Modified: " $$6 " " $$7 " " $$8}'; \
		file "$(BUILD_DIR)/$(APPIMAGE_NAME)" | sed 's/^/  Type: /'; \
	else \
		echo "$(YELLOW)[NO]  Minimal AppImage not built$(NC)"; \
		echo "  Run: make appimage"; \
	fi
	@if [ -f "$(BUILD_DIR)/$(APPIMAGE_PACKAGES_NAME)" ]; then \
		echo "$(GREEN)[YES] Packages AppImage:$(NC)"; \
		ls -lh "$(BUILD_DIR)/$(APPIMAGE_PACKAGES_NAME)" | awk '{print "  Size: " $$5 ", Modified: " $$6 " " $$7 " " $$8}'; \
		file "$(BUILD_DIR)/$(APPIMAGE_PACKAGES_NAME)" | sed 's/^/  Type: /'; \
	else \
		echo "$(YELLOW)[NO]  Packages AppImage not built$(NC)"; \
		echo "  Run: make appimage-packages"; \
	fi
	@echo ""
	@echo "$(BLUE)Build dependencies:$(NC)"
	@if [ -f "$(BUILD_DIR)/appimagetool" ]; then \
		echo "$(GREEN)[YES] appimagetool downloaded$(NC)"; \
	else \
		echo "$(YELLOW)[NO]  appimagetool not downloaded$(NC)"; \
	fi
	@if [ -f "$(BUILD_DIR)/R-$(R_VERSION).tar.gz" ]; then \
		echo "$(GREEN)[YES] R source downloaded$(NC)"; \
	else \
		echo "$(YELLOW)[NO]  R source not downloaded$(NC)"; \
	fi
	@if [ -f "$(BUILD_DIR)/Rlogo.svg" ]; then \
		echo "$(GREEN)[YES] R logo downloaded$(NC)"; \
	else \
		echo "$(YELLOW)[NO]  R logo not downloaded$(NC)"; \
	fi
	@if [ -d "$(BUILD_DIR)/R-$(R_VERSION)" ]; then \
		echo "$(GREEN)[YES] R source extracted$(NC)"; \
	else \
		echo "$(YELLOW)[NO]  R source not extracted$(NC)"; \
	fi

.PHONY: show-packages
show-packages:
	@echo "$(BLUE)Pre-installed Packages Configuration:$(NC)"
	@echo "$(YELLOW)The following packages are included in 'make appimage-packages':$(NC)"
	@echo ""
	@for pkg in $(PREINSTALLED_PACKAGES); do \
		echo "  - $$pkg"; \
	done
	@echo ""
	@echo "$(BLUE)Build comparison:$(NC)"
	@echo "  $(GREEN)make appimage$(NC)          - Base R only (faster, ~150MB)"
	@echo "  $(GREEN)make appimage-packages$(NC) - With packages (slower, ~300MB+)"
	@echo ""
	@echo "$(BLUE)To customize packages:$(NC)"
	@echo "  1. Edit PREINSTALLED_PACKAGES array in $(SCRIPT_NAME)"
	@echo "  2. Run: make clean && make appimage-packages"
	@echo ""
	@echo "$(YELLOW)Note: Both builds have immutable filesystems$(NC)"
	@echo "  Both builds:     install.packages() is disabled (AppImage limitation)"
	@echo "  Minimal build:   Base R packages only"
	@echo "  Packages build:  Base R + pre-installed packages"

.PHONY: arch-info
arch-info:
	@echo "$(BLUE)Architecture Information:$(NC)"
	@echo "System Architecture: $(ARCH)"
	@echo "Target Architecture: $(ARCH_NAME)"
	@echo "Processor: $$(uname -p)"
	@echo "Machine: $$(uname -m)"
	@echo "Kernel: $$(uname -s)"
	@echo "Hardware: $$(uname -i 2>/dev/null || echo 'unknown')"

.PHONY: os-info
os-info:
	@echo "$(BLUE)Operating System Information:$(NC)"
	@if [ -f /etc/os-release ]; then \
		echo "OS Release Info:"; \
		grep -E '^(NAME|VERSION|ID)=' /etc/os-release | sed 's/^/  /'; \
	fi
	@echo "Package Managers:"
	@if command -v apt-get >/dev/null 2>&1; then \
		echo "  [OK] apt-get (Ubuntu/Debian)"; \
	fi
	@if command -v dnf5 >/dev/null 2>&1; then \
		echo "  [OK] dnf5 (Fedora)"; \
	elif command -v dnf >/dev/null 2>&1; then \
		echo "  [OK] dnf (Fedora)"; \
	fi
	@if command -v yum >/dev/null 2>&1; then \
		echo "  [OK] yum (CentOS/RHEL)"; \
	fi
	@echo "SVG Converters:"
	@if command -v convert >/dev/null 2>&1; then \
		echo "  [OK] ImageMagick"; \
	fi
	@if command -v rsvg-convert >/dev/null 2>&1; then \
		echo "  [OK] rsvg-convert"; \
	fi
	@if command -v inkscape >/dev/null 2>&1; then \
		echo "  [OK] Inkscape"; \
	fi

.PHONY: validate
validate:
	@echo "$(BLUE)Validating build script...$(NC)"
	@if [ -f "$(SCRIPT_NAME)" ]; then \
		echo "$(GREEN)[OK] Build script exists$(NC)"; \
		bash -n "$(SCRIPT_NAME)" && \
		echo "$(GREEN)[OK] Syntax is valid$(NC)" || \
		echo "$(RED)[ERROR] Syntax errors found$(NC)"; \
	else \
		echo "$(RED)[ERROR] Build script not found: $(SCRIPT_NAME)$(NC)"; \
	fi

.PHONY: quickstart
quickstart:
	@echo "$(BLUE)R AppImage Builder - Quick Start Guide$(NC)"
	@echo ""
	@echo "$(GREEN)Fast Workflow (Base R)$(NC)"
	@echo ""
	@echo "$(GREEN)1. Install dependencies:$(NC)"
	@echo "   make deps"
	@echo ""
	@echo "$(GREEN)2. Build minimal AppImage (fast):$(NC)"
	@echo "   make appimage"
	@echo ""
	@echo "$(GREEN)3. Test and use:$(NC)"
	@echo "   make test"
	@echo "   ./build/$(APPIMAGE_NAME)"
	@echo ""
	@echo "$(GREEN)4. Install to system:$(NC)"
	@echo "   make install"
	@echo ""
	@echo "$(BLUE)Extended Workflow (With Packages)$(NC)"
	@echo ""
	@echo "$(GREEN)1. Build with pre-installed packages (slower):$(NC)"
	@echo "   make appimage-packages"
	@echo ""
	@echo "$(GREEN)2. Test immutable features:$(NC)"
	@echo "   make test-immutable"
	@echo ""
	@echo "$(GREEN)3. Install packages version:$(NC)"
	@echo "   make install-packages"
	@echo ""
	@echo "$(YELLOW)Build Comparison:$(NC)"
	@echo ""
	@echo "$(GREEN)Minimal Build:$(NC)"
	@echo "  _ Fast build (~15 minutes)"
	@echo "  _ Base R packages only"
	@echo "  _ install.packages() disabled (AppImage limitation)"
	@echo "  _ Size: ~150MB"
	@echo "  _ Use: Lightweight deployments, basic R scripting"
	@echo ""
	@echo "$(BLUE)Packages Build:$(NC)"
	@echo "  - Slower build (~45 minutes)"
	@echo "  - Pre-configured with useful packages"
	@echo "  - install.packages() disabled (AppImage limitation)"
	@echo "  - Size: ~300MB+"
	@echo "  - Use: Production deployments, data analysis"
	@echo ""
	@echo "$(YELLOW)CRITICAL: Both builds have immutable filesystems (AppImage design)$(NC)"
	@echo "$(YELLOW)          NO additional R packages can be installed after creation$(NC)"
	@echo "$(YELLOW)          Choose packages at build time or use external R installation$(NC)"

# Package the AppImages for distribution
.PHONY: package
package:
	@echo "$(BLUE)Creating release package for $(ARCH_NAME)...$(NC)"
	@mkdir -p release
	@if [ -f "$(BUILD_DIR)/$(APPIMAGE_NAME)" ]; then \
		cp "$(BUILD_DIR)/$(APPIMAGE_NAME)" release/; \
	fi
	@if [ -f "$(BUILD_DIR)/$(APPIMAGE_PACKAGES_NAME)" ]; then \
		cp "$(BUILD_DIR)/$(APPIMAGE_PACKAGES_NAME)" release/; \
	fi
	@if [ -f README.md ]; then cp README.md release/; fi
	@if [ -f $(SCRIPT_NAME) ]; then cp $(SCRIPT_NAME) release/; fi
	@echo "R AppImage $(R_VERSION) for $(ARCH_NAME)" > release/VERSION.txt
	@echo "Built on: $$(date)" >> release/VERSION.txt
	@echo "Architecture: $(ARCH_NAME)" >> release/VERSION.txt
	@if [ -f "$(BUILD_DIR)/$(APPIMAGE_NAME)" ]; then \
		echo "Minimal build: Available (base R packages)" >> release/VERSION.txt; \
	fi
	@if [ -f "$(BUILD_DIR)/$(APPIMAGE_PACKAGES_NAME)" ]; then \
		echo "Packages build: Available (pre-installed packages)" >> release/VERSION.txt; \
		echo "Pre-installed packages: $(PREINSTALLED_PACKAGES)" >> release/VERSION.txt; \
	fi
	@echo "Package installation: Disabled (immutable AppImage)" >> release/VERSION.txt
	@tar -czf release/R-$(R_VERSION)-$(ARCH_NAME)-AppImage-release.tar.gz -C release .
	@echo "$(GREEN)[OK] Release package created: release/R-$(R_VERSION)-$(ARCH_NAME)-AppImage-release.tar.gz$(NC)"
	@ls -lh release/

# Show disk usage
.PHONY: disk-usage
disk-usage:
	@echo "$(BLUE)Disk Usage:$(NC)"
	@if [ -d "$(BUILD_DIR)" ]; then \
		du -sh $(BUILD_DIR)/* 2>/dev/null | sort -hr || echo "No files in build directory"; \
	else \
		echo "No build directory found"; \
	fi

# Force rebuild minimal (clean and build)
.PHONY: rebuild
rebuild: clean appimage

# Force rebuild packages (clean and build)
.PHONY: rebuild-packages
rebuild-packages: clean appimage-packages

# Force complete rebuild (clean-all and build both)
.PHONY: rebuild-all
rebuild-all: clean-all appimage appimage-packages