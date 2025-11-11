APP=SpaceCadet
PLIST=com.apple.space-cadet.plist
LAUNCHAGENT_DIR=$(HOME)/Library/LaunchAgents
BIN=.build/release/$(APP)

# SwiftLint
XCODE_APP=/Applications/Xcode.app/Contents/Developer
STRICT?=0

.PHONY: build release run test install-agent unload-agent lint lint-strict lint-fix app-build

lint:
	@command -v swiftlint >/dev/null 2>&1 || { echo "SwiftLint not installed. Install with: brew install swiftlint"; exit 1; }
	@# Prefer full Xcode toolchain for sourcekitd to avoid SwiftLint crash
	@if [ -d "$(XCODE_APP)" ]; then \
		echo "Running SwiftLint with DEVELOPER_DIR=$(XCODE_APP)"; \
		DEVELOPER_DIR=$(XCODE_APP) swiftlint $(if $(filter 1,$(STRICT)),--strict,); \
	else \
		echo "Running SwiftLint with current toolchain"; \
		swiftlint $(if $(filter 1,$(STRICT)),--strict,); \
	fi

lint-strict:
	STRICT=1 $(MAKE) lint

.PHONY: lint-analyze
lint-analyze:
	@command -v swiftlint >/dev/null 2>&1 || { echo "SwiftLint not installed. Install with: brew install swiftlint"; exit 1; }
	@if [ -d "$(XCODE_APP)" ]; then \
		DEVELOPER_DIR=$(XCODE_APP) swiftlint analyze --compiler-log-path swiftlint.log || true; \
	else \
		swiftlint analyze --compiler-log-path swiftlint.log || true; \
	fi
.PHONY: lint-fix
lint-fix:
	@command -v swiftlint >/dev/null 2>&1 || { echo "SwiftLint not installed. Install with: brew install swiftlint"; exit 1; }
	@if [ -d "$(XCODE_APP)" ]; then \
		DEVELOPER_DIR=$(XCODE_APP) swiftlint --fix; \
	else \
		swiftlint --fix; \
	fi

.PHONY: app-build
app-build:
	@echo "Building SpaceCadetApp (Xcode Release)"
	xcodebuild -project SpaceCadetApp/SpaceCadetApp.xcodeproj -scheme SpaceCadetApp -configuration Release -derivedDataPath build-app | xcpretty || true
	@echo "App build artifacts at build-app/Build/Products/Release/Space Cadet.app"

.PHONY: icons
icons:
	@echo "Generating AppIcon set from assets/space_cadet_icon.svg"
	./scripts/gen-appicon.sh assets/space_cadet_icon.svg
	@echo "Done. See SpaceCadetApp/SpaceCadetApp/Assets.xcassets/AppIcon.appiconset"

build: lint
	swift build

release: lint
	swift build -c release

run:
	swift run $(APP)

test: lint
	swift test

install-agent: release
	mkdir -p $(LAUNCHAGENT_DIR)
	cp scripts/$(PLIST) $(LAUNCHAGENT_DIR)/$(PLIST)
	launchctl unload $(LAUNCHAGENT_DIR)/$(PLIST) 2>/dev/null || true
	launchctl load $(LAUNCHAGENT_DIR)/$(PLIST)

	unload-agent:
	launchctl unload $(LAUNCHAGENT_DIR)/$(PLIST)

.PHONY: clean
clean:
	rm -rf .build build-app SpaceCadetApp/build SpaceCadetApp/SpaceCadetApp/build SpaceCadetApp/SpaceCadetApp/DerivedData
	echo "Cleaned build artifacts."
