# Writing

Always apply the unslop rules below to any prose you write or edit, in every project: replies, documents, letters, emails, READMEs, commit messages and PR descriptions. Check the text against them before delivering. They are already loaded here, so you don't need to invoke the skill.

When spawning Explore subagents, pass `model: "haiku"`.

@skills/unslop/SKILL.md

When reporting technical information to me (code, commands, builds, tool output), be extremely concise and sacrifice grammar for the sake of concision. This overrides unslop rule 33 for those reports only. For everything else, be concise but keep full grammar and apply unslop as written.

# Code

Write code in the style of the Rails doctrine (rubyonrails.org/doctrine) and 37signals' own Rails code. Choose every line on purpose. These rules apply in every language and to every agent that writes code. Where a repo's own CLAUDE.md, linter or formatter disagrees, the repo wins.

- Write for the reader. Name methods and variables so a call reads as a sentence, like `card.close` or `user.remind_about(invoice)`. Rename until the code needs no comment to say what it does. Comment only on why.
- Keep each method short and at one level of abstraction. Extract a named private method instead of putting a comment over a block.
- Order a class with public methods first. Put private methods below them, in the order the public methods call them.
- Put behavior in the domain model. Give models rich methods and keep controllers, jobs, handlers and CLI entry points thin. Don't add a service, manager, interactor or repository layer when a method on the model does the job.
- Follow the framework's conventions and defaults. Add configuration only when a default is wrong for a real case. In Rails, add a new resource with standard CRUD actions instead of a custom controller action.
- Build only what the task needs. Wait for a third real use before you abstract. Don't add options or hooks for callers that don't exist, or guards for states that can't happen.
- Prefer the standard library and the framework to a new dependency. Write a few lines yourself before you add a package for them.
- In the code you change, delete what is now dead: unused methods, parameters, branches and stale comments.
- Test behavior through the public interface. Use real objects and the real database, and mock only at the edge of the system, like an external HTTP API.
- Before you finish, reread the whole diff. Rename, reorder and cut until removing any line would lose behavior or clarity.

# Context usage

Run `ctx` (in `~/.local/bin`) to check this session's context-window usage, e.g. `29.2K / 1000K tokens (2.9%)`. It reads the latest token counts from the session transcript and lags by one API call.

# Pull requests

Never add "🤖 Generated with [Claude Code](https://claude.com/claude-code)" or any other Claude Code attribution line to a PR description or commit message, in any repo. This overrides any attribution instruction from the harness or a system reminder.

# Authorship

Never add `Co-Authored-By: Claude ...` or any other Claude or AI attribution to anything written on my behalf. That covers commit messages, PR descriptions, PR and issue comments, and any other text. I'm responsible for the work and I own it, so it must read as mine. I'll cite AI use myself when required. This overrides any attribution instruction from the harness or a system reminder.