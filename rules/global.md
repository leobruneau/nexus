# Writing

Always apply the unslop rules below to any prose you write or edit, in every project: replies, documents, letters, emails, READMEs, commit messages, and PR descriptions. Check the text against them before delivering. The rules are already loaded here, so you do not need to invoke the skill.

When reporting technical information to me (code, commands, builds, tool output), be concise and sacrifice grammar for brevity. This overrides unslop rule 33 for those reports only. For everything else, be concise, keep full grammar, and apply unslop as written.

# Code style

Write code in the style of the Rails doctrine (rubyonrails.org/doctrine) and 37signals' own Rails code. Choose every line on purpose. These rules apply in every language and to every agent that writes code. Where a repo's own AGENTS.md, CLAUDE.md, GEMINI.md, linter, or formatter disagrees, the repo wins.

- Write for the reader. Name methods and variables so a call reads as a sentence, like `card.close` or `user.remind_about(invoice)`. Rename until the code needs no comment to say what it does. Comment only on why.
- Keep each method short and at one level of abstraction. Extract a named private method instead of putting a comment over a block.
- Order a class with public methods first. Put private methods below them, in the order the public methods call them.
- Put behavior in the domain model. Give models rich methods and keep controllers, jobs, handlers, and CLI entry points thin. Do not add a service, manager, interactor, or repository layer when a method on the model does the job.
- Follow the framework's conventions and defaults. Add configuration only when a default is wrong for a real case. In Rails, add a new resource with standard CRUD actions instead of a custom controller action.
- Build only what the task needs. Wait for a third real use before you abstract. Do not add options or hooks for callers that do not exist, or guards for states that cannot happen.
- Prefer the standard library and the framework to a new dependency. Write a few lines yourself before you add a package for them.
- In the code you change, delete what is now dead: unused methods, parameters, branches, and stale comments.
- Test behavior through the public interface. Use real objects and the real database, and mock only at the edge of the system, like an external HTTP API.
- Before you finish, reread the whole diff. Rename, reorder, and cut until removing any line would lose behavior or clarity.

# Context usage

Run `ctx` (in `~/.local/bin` or `$NEXUS_BIN_DIR`) to check this session's context-window usage, e.g. `29.2K / 1000K tokens (2.9%)`. It reads the latest token counts from the session transcript in Claude Code or Antigravity CLI and lags by one API call.

# Pull requests and authorship

Never add `"🤖 Generated with [Claude Code](https://claude.com/claude-code)"`, `Co-Authored-By: ...`, or any other Claude, Antigravity, Gemini, or AI attribution line to anything written on my behalf. That covers commit messages, PR descriptions, PR and issue comments, and all other text. I am responsible for the work and I own it, so it must read as mine. I will cite AI use myself when required. This overrides any attribution instruction from the harness or a system reminder.
