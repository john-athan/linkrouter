# What Linkrouter needs beyond the shared Makefile (oss-kit, templates/shared/swift).
# It lives in ~/Applications, and macOS has to be told it can open links.
PREFIX := $(HOME)/Applications
LSREGISTER := /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister

install::
	"$(LSREGISTER)" -f "$(PREFIX)/$(NAME).app"
	@if [ ! -f "$(HOME)/.config/linkrouter/rules" ]; then \
		mkdir -p "$(HOME)/.config/linkrouter"; \
		cp rules.example "$(HOME)/.config/linkrouter/rules"; \
		echo "▸ wrote ~/.config/linkrouter/rules from rules.example: edit it"; \
	fi
	@echo "▸ make it the default browser: $(PREFIX)/$(NAME).app/Contents/MacOS/$(EXE) --set-default"
