install:
	mkdir -p "$${HOME}/.claude/skills"
	ln -f -s -n "$(shell pwd)/CLAUDE.md" "$${HOME}/.claude/CLAUDE.md"
	for skill in skills/*/; do ln -f -s -n "$(shell pwd)/$${skill%/}" "$${HOME}/.claude/skills/$$(basename "$${skill}")"; done
.PHONY: install
