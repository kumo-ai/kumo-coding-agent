CLAUDE_SKILLS_DIR := $(HOME)/.claude/skills
CODEX_SKILLS_DIR := $(HOME)/.agents/skills
SKILL_NAMES := ds-agent-issue ds-agent-pr
CLAUDE_REPO_SKILLS := $(CURDIR)/.claude/skills
CODEX_REPO_SKILLS := $(CURDIR)/.agents/skills

.PHONY: \
	install-slash-commands \
	install-claude-slash-commands \
	install-codex-slash-commands \
	uninstall-slash-commands \
	uninstall-claude-slash-commands \
	uninstall-codex-slash-commands

install-slash-commands: install-claude-slash-commands install-codex-slash-commands
	@echo ""
	@echo "Done. Commands available in any new Claude Code or Codex session."

install-claude-slash-commands:
	@mkdir -p $(CLAUDE_SKILLS_DIR)
	@$(foreach skill,$(SKILL_NAMES), \
		if [ -L "$(CLAUDE_SKILLS_DIR)/$(skill)" ]; then \
			echo "  updated  Claude Code:$(skill) (replaced existing symlink)"; \
			rm "$(CLAUDE_SKILLS_DIR)/$(skill)"; \
		elif [ -e "$(CLAUDE_SKILLS_DIR)/$(skill)" ]; then \
			echo "  skipped  Claude Code:$(skill) (non-symlink already exists)"; \
			false; \
		fi; \
		ln -s "$(CLAUDE_REPO_SKILLS)/$(skill)" "$(CLAUDE_SKILLS_DIR)/$(skill)" && \
		echo "  installed  Claude Code:$(skill)"; \
	)
	@echo ""
	@echo "Claude Code commands available in any new session:"
	@echo "  /ds-agent-import   Copy DS-agent into a project"
	@echo "  /ds-agent-issue    File a bug or feature request"
	@echo "  /ds-agent-pr       Fix a doc and open a PR"

install-codex-slash-commands:
	@mkdir -p $(CODEX_SKILLS_DIR)
	@$(foreach skill,$(SKILL_NAMES), \
		if [ -L "$(CODEX_SKILLS_DIR)/$(skill)" ]; then \
			echo "  updated  Codex:$(skill) (replaced existing symlink)"; \
			rm "$(CODEX_SKILLS_DIR)/$(skill)"; \
		elif [ -e "$(CODEX_SKILLS_DIR)/$(skill)" ]; then \
			echo "  skipped  Codex:$(skill) (non-symlink already exists)"; \
			false; \
		fi; \
		ln -s "$(CODEX_REPO_SKILLS)/$(skill)" "$(CODEX_SKILLS_DIR)/$(skill)" && \
		echo "  installed  Codex:$(skill)"; \
	)
	@echo ""
	@echo "Codex skills available in any new session:"
	@echo "  /ds-agent-import   Copy DS-agent into a project"
	@echo "  /ds-agent-issue    File a bug or feature request"
	@echo "  /ds-agent-pr       Fix a doc and open a PR"

uninstall-slash-commands: uninstall-claude-slash-commands uninstall-codex-slash-commands
	@echo ""
	@echo "Done. Commands removed from Claude Code and Codex."

uninstall-claude-slash-commands:
	@$(foreach skill,$(SKILL_NAMES), \
		if [ -L "$(CLAUDE_SKILLS_DIR)/$(skill)" ]; then \
			rm "$(CLAUDE_SKILLS_DIR)/$(skill)"; \
			echo "  removed  Claude Code:$(skill)"; \
		else \
			echo "  skipped  Claude Code:$(skill) (not a symlink or doesn't exist)"; \
		fi; \
	)

uninstall-codex-slash-commands:
	@$(foreach skill,$(SKILL_NAMES), \
		if [ -L "$(CODEX_SKILLS_DIR)/$(skill)" ]; then \
			rm "$(CODEX_SKILLS_DIR)/$(skill)"; \
			echo "  removed  Codex:$(skill)"; \
		else \
			echo "  skipped  Codex:$(skill) (not a symlink or doesn't exist)"; \
		fi; \
	)
