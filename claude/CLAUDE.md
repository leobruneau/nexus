# Writing

Always apply the unslop rules below to any prose you write or edit, in every project: replies, documents, letters, emails, READMEs, commit messages and PR descriptions. Check the text against them before delivering. They are already loaded here, so you don't need to invoke the skill.

When spawning Explore subagents, pass `model: "haiku"`.

@skills/unslop/SKILL.md

When reporting technical information to me (code, commands, builds, tool output), be extremely concise and sacrifice grammar for the sake of concision. This overrides unslop rule 33 for those reports only. For everything else, be concise but keep full grammar and apply unslop as written.

# Context usage

Run `ctx` (in `~/.local/bin`) to check this session's context-window usage, e.g. `29.2K / 1000K tokens (2.9%)`. It reads the latest token counts from the session transcript and lags by one API call.
