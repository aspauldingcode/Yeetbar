# DISABLE TITLEBARS Makefile
# Simple build automation for DISABLE TITLEBARS Ammonia tweak

# Variables
PROJECT_NAME = Yeetbar
SWIFT_SOURCE = Sources/DisableTitlebars/DisableTitlebars.swift
OBJC_SOURCE = Sources/DisableTitlebars/YeetbarLoader.m
BUILD_DIR = .build
DYLIB_PATH = $(BUILD_DIR)/Yeetbar.dylib
INSTALL_PATH = /var/ammonia/core/tweaks

# Color definitions for output
GREEN := \033[32m
YELLOW := \033[33m
BLUE := \033[34m
RED := \033[31m
CYAN := \033[36m
BOLD := \033[1m
RESET := \033[0m

# Default target
.PHONY: all
all: build

# Build the dylib from single Swift file
.PHONY: build
build:
	@echo -e "$(CYAN)Building $(PROJECT_NAME) universal dylib from single Swift file...$(RESET)"
	@mkdir -p $(BUILD_DIR)
	@echo -e "$(YELLOW)Building for arm64...$(RESET)"
	swiftc -emit-library -o $(BUILD_DIR)/$(PROJECT_NAME)_arm64.dylib $(SWIFT_SOURCE) $(OBJC_SOURCE) \
		-target arm64-apple-macos11.0 \
		-Xlinker -install_name -Xlinker @executable_path/$(PROJECT_NAME).dylib \
		-framework Foundation -framework AppKit -framework Cocoa
	@echo -e "$(YELLOW)Building for arm64e...$(RESET)"
	swiftc -emit-library -o $(BUILD_DIR)/$(PROJECT_NAME)_arm64e.dylib $(SWIFT_SOURCE) $(OBJC_SOURCE) \
		-target arm64e-apple-macos11.0 \
		-Xlinker -install_name -Xlinker @executable_path/$(PROJECT_NAME).dylib \
		-framework Foundation -framework AppKit -framework Cocoa
	@echo -e "$(YELLOW)Building for x86_64...$(RESET)"
	swiftc -emit-library -o $(BUILD_DIR)/$(PROJECT_NAME)_x86_64.dylib $(SWIFT_SOURCE) $(OBJC_SOURCE) \
		-target x86_64-apple-macos11.0 \
		-Xlinker -install_name -Xlinker @executable_path/$(PROJECT_NAME).dylib \
		-framework Foundation -framework AppKit -framework Cocoa
	@echo -e "$(BLUE)Creating universal FAT binary...$(RESET)"
	lipo -create \
		$(BUILD_DIR)/Yeetbar_arm64.dylib \
		$(BUILD_DIR)/Yeetbar_arm64e.dylib \
		$(BUILD_DIR)/Yeetbar_x86_64.dylib \
		-output $(DYLIB_PATH)
	@echo -e "$(GREEN)Universal dylib created successfully!$(RESET)"
	@echo -e "$(GREEN)Built: $(DYLIB_PATH)$(RESET)"

# Test injection with CrystalFetch
.PHONY: test
test: build
	@echo -e "$(CYAN)Testing $(PROJECT_NAME) injection with CrystalFetch...$(RESET)"
	@if [ ! -f "$(DYLIB_PATH)" ]; then echo -e "$(RED)Error: Dylib not found. Run 'make build' first.$(RESET)"; exit 1; fi
	@echo -e "$(YELLOW)Launching CrystalFetch with dylib injection...$(RESET)"
	@echo -e "$(BLUE)Check Console.app for 'Yeetbar' logs to verify injection$(RESET)"
	DYLD_INSERT_LIBRARIES="$(PWD)/$(DYLIB_PATH)" open -a CrystalFetch
	@echo -e "$(GREEN)CrystalFetch launched! Check Console.app for 'Yeetbar' logs.$(RESET)"

# Install the tweak to Ammonia system
.PHONY: install
install: build
	@echo -e "$(CYAN)Installing $(PROJECT_NAME) to $(INSTALL_PATH)...$(RESET)"
	sudo mkdir -p $(INSTALL_PATH)
	sudo rm -f $(INSTALL_PATH)/Yeetbar.dylib $(INSTALL_PATH)/Yeetbar.dylib.blacklist
	sudo cp $(DYLIB_PATH) $(INSTALL_PATH)/Yeetbar.dylib
	@if [ -f "Yeetbar.dylib.blacklist" ]; then \
		sudo cp Yeetbar.dylib.blacklist $(INSTALL_PATH)/Yeetbar.dylib.blacklist; \
	fi
	sudo chown root:wheel $(INSTALL_PATH)/Yeetbar.dylib
	sudo chmod 755 $(INSTALL_PATH)/Yeetbar.dylib
	@if [ -f "$(INSTALL_PATH)/Yeetbar.dylib.blacklist" ]; then \
		sudo chown root:wheel $(INSTALL_PATH)/Yeetbar.dylib.blacklist; \
		sudo chmod 644 $(INSTALL_PATH)/Yeetbar.dylib.blacklist; \
	fi
	@echo -e "$(GREEN)$(PROJECT_NAME) dylib installed successfully!$(RESET)"
	@echo -e "$(YELLOW)Note: Restart applications to see the effect$(RESET)"

# Test with TextEdit
.PHONY: textedit
textedit:
	@echo "🚀 Testing Yeetbar with TextEdit..."
	@pkill -f TextEdit || true
	@sleep 1
	@DYLD_INSERT_LIBRARIES=/var/ammonia/core/tweaks/Yeetbar.dylib open -a TextEdit
	@sleep 3
	@osascript -e 'tell application "TextEdit"' \
		-e 'activate' \
		-e 'make new document' \
		-e 'set text of document 1 to "This is a test document for toolbar preservation.\n\nThis text should help test formatting options."' \
		-e 'end tell'
	@echo "📋 TextEdit launched with Yeetbar and test document created. Check Console.app for logs."

# Test with Finder
.PHONY: finder
finder:
	@echo "🚀 Testing Yeetbar with Finder..."
	@pkill -f Finder || true
	@sleep 1
	@DYLD_INSERT_LIBRARIES=/var/ammonia/core/tweaks/Yeetbar.dylib open -a Finder
	@sleep 3
	@osascript -e 'tell application "Finder"' \
		-e 'activate' \
		-e 'open home' \
		-e 'end tell'
	@echo "📁 Finder launched with Yeetbar and opened home directory. Check Console.app for logs."

# Uninstall the tweak from system
.PHONY: uninstall remove
uninstall remove:
	@echo -e "$(CYAN)Uninstalling $(PROJECT_NAME) from system...$(RESET)"
	sudo rm -f $(INSTALL_PATH)/Yeetbar.dylib
	sudo rm -f $(INSTALL_PATH)/Yeetbar.dylib.blacklist
	@echo -e "$(GREEN)$(PROJECT_NAME) uninstalled successfully!$(RESET)"

# Clean build artifacts
.PHONY: clean
clean:
	@echo -e "$(CYAN)Cleaning build artifacts...$(RESET)"
	rm -rf $(BUILD_DIR)
	@echo -e "$(GREEN)Clean complete!$(RESET)"

# Show file information
.PHONY: info
info: build
	@echo -e "$(CYAN)$(PROJECT_NAME) Dylib Information:$(RESET)"
	@if [ -f "$(DYLIB_PATH)" ]; then \
		echo -e "$(GREEN)File: $(DYLIB_PATH)$(RESET)"; \
		echo -e "$(YELLOW)Size: $$(du -h $(DYLIB_PATH) | cut -f1)$(RESET)"; \
		echo -e "$(BLUE)Architectures:$(RESET)"; \
		lipo -info $(DYLIB_PATH); \
	else \
		echo -e "$(RED)Dylib not found. Run 'make build' first.$(RESET)"; \
	fi

# Show Console.app logs filtered for Yeetbar entries
.PHONY: logs
logs:
	@echo "Filtering Console.app logs for 'Yeetbar' entries..."
	@echo "Checking system logs..."
	tail -f /var/log/system.log 2>/dev/null | grep -i yeetbar || echo "No system.log found, trying alternative..."
	@echo "Checking Console logs with simpler filter..."
	log show --last 5m 2>/dev/null | grep -i yeetbar || echo "No Yeetbar entries found in recent logs"
	@echo "Checking for any DisableTitlebars related logs..."
	log show --last 5m 2>/dev/null | grep -i "DisableTitlebars\|dylib\|inject" | head -10 || echo "No related logs found"

# Help
.PHONY: help
help:
	@echo -e "$(BOLD)DISABLE TITLEBARS Build System$(RESET)"
	@echo ""
	@echo -e "$(CYAN)Available targets:$(RESET)"
	@echo -e "  $(GREEN)build$(RESET)      - Build the dylib from single Swift file"
	@echo -e "  $(GREEN)test$(RESET)       - Test injection with CrystalFetch application"
	@echo -e "  $(GREEN)textedit$(RESET)   - Test with TextEdit application"
	@echo -e "  $(GREEN)finder$(RESET)     - Test with Finder application"
	@echo -e "  $(GREEN)install$(RESET)    - Install tweak to Ammonia system (/var/ammonia/core/tweaks)"
	@echo -e "  $(GREEN)uninstall$(RESET)  - Uninstall tweak from system (alias: remove)"
	@echo -e "  $(GREEN)logs$(RESET)       - Show Console.app logs filtered for 'Yeetbar' entries"
	@echo -e "  $(GREEN)clean$(RESET)      - Clean build artifacts"
	@echo -e "  $(GREEN)info$(RESET)       - Show dylib information and architectures"
	@echo -e "  $(GREEN)help$(RESET)       - Show this help message"
	@echo ""
	@echo -e "$(YELLOW)Usage Examples:$(RESET)"
	@echo -e "  make build     # Build the tweak from single Swift file"
	@echo -e "  make test      # Test with CrystalFetch application"
	@echo -e "  make logs      # Show filtered Console.app logs"
	@echo -e "  make install   # Install to Ammonia tweaks directory"
	@echo -e "  make remove    # Remove from system"
	@echo ""
	@echo -e "$(BLUE)Search for 'Yeetbar' in Console.app to verify injection$(RESET)"