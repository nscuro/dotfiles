ifeq ($(shell uname -s),Darwin)
    BWNPM_SRC := bwnpm.macos
else
    BWNPM_SRC := bwnpm.linux
endif

install:
	mkdir -p "$${HOME}/.local/bin"
	ln -f -s "$(shell pwd)/$(BWNPM_SRC)" "$${HOME}/.local/bin/bwnpm"
.PHONY: install
