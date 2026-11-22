# What Linkrouter needs beyond the shared Makefile (oss-kit, templates/shared/swift).
# It installs to /Applications like every app here, puts `linkrouter` on the
# PATH for --which, and tells macOS it can open links.
CLI := yes
LSREGISTER := /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
OLD := $(HOME)/Applications/$(NAME).app

install::
	@# Until 1.1.0 it lived in ~/Applications. The default browser is kept by
	@# bundle identifier, so it moves with the app once the old copy is gone.
	@if [ -d "$(OLD)" ]; then \
		"$(LSREGISTER)" -u "$(OLD)" 2>/dev/null || true; \
		rm -rf "$(OLD)"; \
		echo "▸ removed the old copy in ~/Applications"; \
	fi
	"$(LSREGISTER)" -f "$(PREFIX)/$(NAME).app"
	@if [ ! -f "$(HOME)/.config/linkrouter/rules" ]; then \
		mkdir -p "$(HOME)/.config/linkrouter"; \
		cp rules.example "$(HOME)/.config/linkrouter/rules"; \
		echo "▸ wrote ~/.config/linkrouter/rules from rules.example: edit it"; \
	fi
	@echo "▸ once: $(PREFIX)/$(NAME).app/Contents/MacOS/$(EXE) --set-default"

# The rules are yours and stay. The log goes with the app.
uninstall::
	"$(LSREGISTER)" -u "$(PREFIX)/$(NAME).app" 2>/dev/null || true
	rm -f "$(HOME)/Library/Logs/linkrouter.log"
	@echo "▸ kept ~/.config/linkrouter/rules; pick another default browser in System Settings > Desktop & Dock"
