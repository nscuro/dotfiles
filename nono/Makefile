install:
	mkdir -p "$${HOME}/.config/nono/profiles"
	for profile in profiles/*.json; do ln -f -s "$(shell pwd)/$${profile}" "$${HOME}/.config/nono/profiles/$$(basename "$${profile}")"; done
.PHONY: install
