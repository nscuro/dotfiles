install-all: install-git install-tmux install-vim install-zsh
.PHONY: install-all

install-git:
	cd ./git && $(MAKE) install
.PHONY: install-git

install-tmux:
	cd ./tmux && $(MAKE) install
.PHONY: install-tmux

install-vim:
	cd ./vim && $(MAKE) install
.PHONY: install-vim

install-zsh:
	cd ./zsh && $(MAKE) install
.PHONY: install-zsh
