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

# Engineering discipline

- Prove it works. Verify against the real artifact by running the feature, reading actual output, and inspecting the diff. Proxies and "it compiles" do not count.
- Fix root causes. Trace symptoms to the first wrong decision and fix the pattern, not one site. Add guards only for legitimate states.
- Attack the premise. When two fixes sharing one assumption fail the same check, write the assumption down and test it directly before trying another fix.
- Boundary discipline. Validate and parse raw input at system boundaries such as CLI arguments, config files, network calls, and external APIs. Trust domain types inside and keep business logic in pure functions.
- Make operations idempotent. Derive state-changing steps from current state so retries and partial crashes converge cleanly. Write to a temp file and rename into place.
- Separate before serializing shared state. Give concurrent workers their own files, branches, or worktrees and merge at read time. Use locks only when one shared writer is a real invariant.
- Encode lessons in structure. When a mistake repeats, fix it with architecture, types, a lint, or a test instead of adding more prose rules.

# Workflows and sub-agents

Pick the workflow matching the stage of work. Smaller composable skills in `skills/` already have their descriptions in context.

- `/kickoff`: turns an idea into a settled domain model, spec, and ticket graph.
- `/execute-plan`: implements a spec or ticket graph interactively across `implementer` and `test-runner` sub-agents.
- `/unattended-run`: runs a long backlog or sweep unattended across chained background sessions (`claude --bg` or `rex` + `agy -i`), optionally ingesting `/kickoff` specs and tickets.
- `/review`: runs parallel isolated reviews for standards, spec, proven bugs, blast radius, and hygiene before opening a PR.
- `/improve-setup`: audits recent transcripts and decision logs to refine repo checks, rules, and Nexus skills.

Shared sub-agents: `implementer` executes one planned change, `reviewer` reviews diffs read-only, `test-runner` runs tests and returns only failures, and `comment-sicko` audits or strips unnecessary comments.

# Context usage

Run `ctx` (in `~/.local/bin` or `$NEXUS_BIN_DIR`) to check this session's context-window usage, e.g. `29.2K / 1000K tokens (2.9%)`. It reads the latest token counts from the session transcript in Claude Code or Antigravity CLI and lags by one API call.

At 125k tokens (hook alert or `ctx`), finish the current unit cleanly and do not start large new units. At 150k tokens in a main session, hand off promptly using the `handoff` skill (subagents finish and return to their parent; `/unattended-run` orchestrators follow `MISSION.md` instead).

# Pull requests and authorship

Never add `"🤖 Generated with [Claude Code](https://claude.com/claude-code)"`, `Co-Authored-By: ...`, or any other Claude, Antigravity, Gemini, or AI attribution line to anything written on my behalf. That covers commit messages, PR descriptions, PR and issue comments, and all other text. I am responsible for the work and I own it, so it must read as mine. I will cite AI use myself when required. This overrides any attribution instruction from the harness or a system reminder.
