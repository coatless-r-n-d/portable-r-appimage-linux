# Makefile for R AppImage Builder
# Multi-Architecture Support (x86_64 and aarch64)

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
SCRIPT_NAME = build-r-appimage.sh

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
	@echo "$(BLUE)R AppImage Builder ($(ARCH_NAME)) - R $(R_VERSION)$(NC)"
	@echo ""
	@echo "$(GREEN)Available targets:$(NC)"
	@echo "  appimage         - Build R AppImage with official logo and repositories"
	@echo "  deps             - Install dependencies (auto-detect OS)"
	@echo "  deps-ubuntu      - Install Ubuntu/Debian dependencies"
	@echo "  deps-fedora      - Install Fedora dependencies"
	@echo "  deps-centos      - Install CentOS/RHEL dependencies"
	@echo "  test             - Test the built AppImage"
	@echo "  install          - Install to ~/.local/bin"
	@echo "  clean            - Clean build artifacts"
	@echo "  clean-all        - Clean everything including downloads"
	@echo "  status           - Show build status"
	@echo "  arch-info        - Show architecture info"
	@echo "  os-info          - Show detected OS info"
	@echo "  validate         - Validate build script syntax"
	@echo "  quickstart       - Show quick start guide"

.PHONY: appimage
appimage: $(SCRIPT_NAME)
	@echo "$(BLUE)Building R $(R_VERSION) AppImage for $(ARCH_NAME)...$(NC)"
	@chmod +x $(SCRIPT_NAME)
	@./$(SCRIPT_NAME)

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
		xz-devel \
		pcre-devel \
		zlib-devel
	@echo "$(GREEN)CentOS/RHEL dependencies installed$(NC)"

.PHONY: test
test:
	@if [ -f "$(BUILD_DIR)/$(APPIMAGE_NAME)" ]; then \
		echo "$(BLUE)Testing AppImage...$(NC)"; \
		chmod +x "$(BUILD_DIR)/$(APPIMAGE_NAME)"; \
		"$(BUILD_DIR)/$(APPIMAGE_NAME)" --version && \
		echo "$(GREEN)✓ AppImage test passed$(NC)" || \
		echo "$(YELLOW)⚠ AppImage exists but test failed$(NC)"; \
	else \
		echo "$(YELLOW)AppImage not found: $(BUILD_DIR)/$(APPIMAGE_NAME)$(NC)"; \
		echo "Run 'make appimage' first"; \
		exit 1; \
	fi

.PHONY: install
install:
	@if [ -f "$(BUILD_DIR)/$(APPIMAGE_NAME)" ]; then \
		echo "$(BLUE)Installing to ~/.local/bin/...$(NC)"; \
		mkdir -p ~/.local/bin; \
		cp "$(BUILD_DIR)/$(APPIMAGE_NAME)" ~/.local/bin/R.AppImage; \
		chmod +x ~/.local/bin/R.AppImage; \
		echo "$(GREEN)✓ Installed: ~/.local/bin/R.AppImage$(NC)"; \
		echo "$(YELLOW)Make sure ~/.local/bin is in your PATH$(NC)"; \
		echo "$(BLUE)Add to ~/.bashrc: export PATH=\"\$$HOME/.local/bin:\$$PATH\"$(NC)"; \
	else \
		echo "$(YELLOW)AppImage not found. Run 'make appimage' first$(NC)"; \
		exit 1; \
	fi

.PHONY: desktop-integration
desktop-integration:
	@echo "$(BLUE)Creating desktop integration...$(NC)"
	@mkdir -p ~/.local/share/applications
	@echo '[Desktop Entry]' > ~/.local/share/applications/R-AppImage.desktop
	@echo 'Name=R Statistical Computing (AppImage)' >> ~/.local/share/applications/R-AppImage.desktop
	@echo 'Comment=R Statistical Computing Environment - Portable' >> ~/.local/share/applications/R-AppImage.desktop
	@echo 'Exec=R.AppImage' >> ~/.local/share/applications/R-AppImage.desktop
	@echo 'Icon=R' >> ~/.local/share/applications/R-AppImage.desktop
	@echo 'Type=Application' >> ~/.local/share/applications/R-AppImage.desktop
	@echo 'Categories=Science;Math;Education;' >> ~/.local/share/applications/R-AppImage.desktop
	@echo 'Terminal=true' >> ~/.local/share/applications/R-AppImage.desktop
	@echo 'StartupNotify=true' >> ~/.local/share/applications/R-AppImage.desktop
	@echo "$(GREEN)✓ Desktop integration created$(NC)"

# Clean build artifacts but keep downloads
.PHONY: clean
clean:
	@echo "$(BLUE)Cleaning build artifacts...$(NC)"
	@if [ -d "$(BUILD_DIR)" ]; then \
		rm -rf $(BUILD_DIR)/R.AppDir; \
		rm -f $(BUILD_DIR)/R-$(R_VERSION)-*.AppImage; \
		echo "$(GREEN)✓ Build artifacts cleaned$(NC)"; \
	else \
		echo "$(YELLOW)No build directory found$(NC)"; \
	fi

# Clean everything including downloads and source
.PHONY: clean-all
clean-all:
	@echo "$(BLUE)Cleaning everything...$(NC)"
	@if [ -d "$(BUILD_DIR)" ]; then \
		rm -rf $(BUILD_DIR); \
		echo "$(GREEN)✓ Everything cleaned (including downloads)$(NC)"; \
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
		echo "$(GREEN)✓ Downloads cleaned$(NC)"; \
	else \
		echo "$(YELLOW)No build directory found$(NC)"; \
	fi

.PHONY: status
status:
	@echo "$(BLUE)Build Status:$(NC)"
	@echo "Architecture: $(ARCH_NAME)"
	@echo "R Version: $(R_VERSION)"
	@echo "Build Directory: $(BUILD_DIR)"
	@echo "Expected AppImage: $(BUILD_DIR)/$(APPIMAGE_NAME)"
	@echo ""
	@if [ -f "$(BUILD_DIR)/$(APPIMAGE_NAME)" ]; then \
		echo "$(GREEN)✓ AppImage exists:$(NC)"; \
		ls -lh "$(BUILD_DIR)/$(APPIMAGE_NAME)"; \
		file "$(BUILD_DIR)/$(APPIMAGE_NAME)"; \
	else \
		echo "$(YELLOW)✗ AppImage not built$(NC)"; \
	fi
	@echo ""
	@if [ -f "$(BUILD_DIR)/appimagetool" ]; then \
		echo "$(GREEN)✓ appimagetool downloaded$(NC)"; \
	else \
		echo "$(YELLOW)✗ appimagetool not downloaded$(NC)"; \
	fi
	@if [ -f "$(BUILD_DIR)/R-$(R_VERSION).tar.gz" ]; then \
		echo "$(GREEN)✓ R source downloaded$(NC)"; \
	else \
		echo "$(YELLOW)✗ R source not downloaded$(NC)"; \
	fi
	@if [ -f "$(BUILD_DIR)/Rlogo.svg" ]; then \
		echo "$(GREEN)✓ R logo downloaded$(NC)"; \
	else \
		echo "$(YELLOW)✗ R logo not downloaded$(NC)"; \
	fi
	@if [ -d "$(BUILD_DIR)/R-$(R_VERSION)" ]; then \
		echo "$(GREEN)✓ R source extracted$(NC)"; \
	else \
		echo "$(YELLOW)✗ R source not extracted$(NC)"; \
	fi

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
		echo "  ✓ apt-get (Ubuntu/Debian)"; \
	fi
	@if command -v dnf5 >/dev/null 2>&1; then \
		echo "  ✓ dnf5 (Fedora)"; \
	elif command -v dnf >/dev/null 2>&1; then \
		echo "  ✓ dnf (Fedora)"; \
	fi
	@if command -v yum >/dev/null 2>&1; then \
		echo "  ✓ yum (CentOS/RHEL)"; \
	fi
	@echo "SVG Converters:"
	@if command -v convert >/dev/null 2>&1; then \
		echo "  ✓ ImageMagick"; \
	fi
	@if command -v rsvg-convert >/dev/null 2>&1; then \
		echo "  ✓ rsvg-convert"; \
	fi
	@if command -v inkscape >/dev/null 2>&1; then \
		echo "  ✓ Inkscape"; \
	fi

.PHONY: validate
validate:
	@echo "$(BLUE)Validating build script...$(NC)"
	@if [ -f "$(SCRIPT_NAME)" ]; then \
		echo "$(GREEN)✓ Build script exists$(NC)"; \
		bash -n "$(SCRIPT_NAME)" && \
		echo "$(GREEN)✓ Syntax is valid$(NC)" || \
		echo "$(RED)✗ Syntax errors found$(NC)"; \
	else \
		echo "$(RED)✗ Build script not found: $(SCRIPT_NAME)$(NC)"; \
	fi

.PHONY: quickstart
quickstart:
	@echo "$(BLUE)R AppImage Builder - Quick Start$(NC)"
	@echo ""
	@echo "$(GREEN)1. Install dependencies (auto-detect OS + SVG converters):$(NC)"
	@echo "   make deps"
	@echo ""
	@echo "$(GREEN)2. Build AppImage (downloads R logo, configures repos):$(NC)"
	@echo "   make appimage"
	@echo ""
	@echo "$(GREEN)3. Test AppImage:$(NC)"
	@echo "   make test"
	@echo ""
	@echo "$(GREEN)4. Install to system:$(NC)"
	@echo "   make install"
	@echo ""
	@echo "$(GREEN)5. Add desktop integration:$(NC)"
	@echo "   make desktop-integration"
	@echo ""
	@echo "$(BLUE)Package installation example:$(NC)"
	@echo "   ./build/$(APPIMAGE_NAME) -e \"install.packages('ggplot2')\""
	@echo ""
	@echo "$(BLUE)User library location:$(NC)"
	@echo "   ~/.local/lib/R/AppImage/$(R_VERSION)/library"
	@echo ""
	@echo "$(BLUE)Other useful commands:$(NC)"
	@echo "   make status      - Check build status"
	@echo "   make os-info     - Show OS information"
	@echo "   make arch-info   - Show architecture info"
	@echo "   make clean       - Clean build artifacts"
	@echo "   make help        - Show all available targets"

# Package the AppImage for distribution
.PHONY: package
package: appimage
	@echo "$(BLUE)Creating release package for $(ARCH_NAME)...$(NC)"
	@mkdir -p release
	@cp "$(BUILD_DIR)/$(APPIMAGE_NAME)" release/
	@if [ -f README.md ]; then cp README.md release/; fi
	@if [ -f $(SCRIPT_NAME) ]; then cp $(SCRIPT_NAME) release/; fi
	@echo "R AppImage $(R_VERSION) for $(ARCH_NAME)" > release/VERSION.txt
	@echo "Built on: $$(date)" >> release/VERSION.txt
	@echo "Architecture: $(ARCH_NAME)" >> release/VERSION.txt
	@echo "Features: Official R logo, pre-configured repositories" >> release/VERSION.txt
	@echo "User library: ~/.local/lib/R/AppImage/$(R_VERSION)/library" >> release/VERSION.txt
	@tar -czf release/R-$(R_VERSION)-$(ARCH_NAME)-AppImage-release.tar.gz -C release .
	@echo "$(GREEN)✓ Release package created: release/R-$(R_VERSION)-$(ARCH_NAME)-AppImage-release.tar.gz$(NC)"
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

# Force rebuild (clean and build)
.PHONY: rebuild
rebuild: clean appimage

# Force complete rebuild (clean-all and build)
.PHONY: rebuild-all
rebuild-all: clean-all appimage

# Test package installation
.PHONY: test-packages
test-packages:
	@if [ -f "$(BUILD_DIR)/$(APPIMAGE_NAME)" ]; then \
		echo "$(BLUE)Testing package installation...$(NC)"; \
		"$(BUILD_DIR)/$(APPIMAGE_NAME)" -e "install.packages('jsonlite', quiet=TRUE); library(jsonlite); cat('Package installation successful!\n')"; \
		echo "$(GREEN)✓ Package installation test completed$(NC)"; \
	else \
		echo "$(YELLOW)AppImage not found. Run 'make appimage' first$(NC)"; \
		exit 1; \
	fi
