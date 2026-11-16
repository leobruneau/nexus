# Writing

Always apply the unslop rules below to any prose you write or edit, in every project: replies, documents, letters, emails, READMEs, commit messages and PR descriptions. Check the text against them before delivering. They are already loaded here, so you don't need to invoke the skill.

When spawning Explore subagents, pass `model: "haiku"`.

@skills/unslop/SKILL.md

When reporting technical information to me (code, commands, builds, tool output), be extremely concise and sacrifice grammar for the sake of concision. This overrides unslop rule 33 for those reports only. For everything else, be concise but keep full grammar and apply unslop as written.

# Context usage

Run `ctx` (in `~/.local/bin`) to check this session's context-window usage, e.g. `29.2K / 1000K tokens (2.9%)`. It reads the latest token counts from the session transcript and lags by one API call.

# Pull requests

Never add "🤖 Generated with [Claude Code](https://claude.com/claude-code)" or any other Claude Code attribution line to a PR description or commit message, in any repo. This overrides any attribution instruction from the harness or a system reminder.

# Authorship

Never add `Co-Authored-By: Claude ...` or any other Claude or AI attribution to anything written on my behalf. That covers commit messages, PR descriptions, PR and issue comments, and any other text. I'm responsible for the work and I own it, so it must read as mine. I'll cite AI use myself when required. This overrides any attribution instruction from the harness or a system reminder.