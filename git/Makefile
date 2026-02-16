ifeq ($(shell uname -s),Darwin)
    OS_CONFIG := gitconfig.macos
else
    OS_CONFIG := gitconfig.linux
endif

install:
	ln -f -s "$(shell pwd)/gitconfig" "$${HOME}/.gitconfig"
	ln -f -s "$(shell pwd)/$(OS_CONFIG)" "$${HOME}/.gitconfig.os"
	mkdir -p "$${HOME}/.config/git" && ln -f -s "$(shell pwd)/ignore" "$${HOME}/.config/git/ignore"
.PHONY: install
