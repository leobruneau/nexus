---
name: blast-radius
description: Find what a change breaks elsewhere before it ships and prove safety by running real code. Use for "blast radius of X", "what could this break", or risky diffs.
disable-model-invocation: true
---

# Blast radius

Find what a change breaks somewhere else before it ships. Use for "blast radius of X", "what could this break", or reviewing a small diff you do not trust yet.

Listing the callers is not the job. Anyone can grep those in a second. The job is the breakage grep will not show you.

## Do not trust your own writeup

A blast-radius writeup that sounds right is worthless. It reads as convincing whether or not it is true. Find the one or two facts the whole change depends on and prove them by running code.

### How sure are you

For each fact the change's safety depends on, get it as far down this list as is cheap, and state where it stopped:

1. You said so. Worthless on its own.
2. You pointed at the line. A real `file:line`, or the library's own source.
3. You showed the bad case cannot happen. You walked the failure step by step and it does not reach.
4. You ran it. A script or test that calls the real code and fails loud if you are wrong.
5. You reproduced it in the running app.

Step 4 is usually one small script that imports the same library the app ships and calls the exact function you are worried about.

## Steps

1. Read the change. Read the diff, the symbols it adds, changes, and deletes, and what it now does differently, including what the diff does not spell out. Pull the PR and its commits if any exist.
2. Find the one fact it is safe because of. Most changes that look risky are safe because of a single fact, such as "this call only drops already-dead cache entries and does nothing else". Find that fact. If it holds, most risky cases clear at once. Spend your time here instead of on a long list of maybes.
3. Look where grep stops. Read the source of the library you call, and check its pinned version and any local patch. Work out when things run, such as microtasks, teardown, or framework lifecycle. Follow what a symbol search misses: the JSON an API returns, a DB column, a wire format, another language reading the same bytes, a feature flag, or code three hops downstream.
4. Be honest about each risk. Give it a real chance of happening and a real cost if it does. Keep the risks you confirmed, and list the ones you checked and cleared separately. Cite a real `file:line` (a search that finds nothing is still an answer), and never make up a caller or an API.
5. Prove the one fact. Write a script or test that runs the real code, run it, and paste what happened.
6. For a big or wide change, spawn 2 independent read-only subagents with the same question and merge their findings.

## What to hand back

- **What it does.** What changed, including the part that is not obvious.
- **The one fact it is safe because of.** State it, say which level on the proof ladder you reached, and show the proof. If you could not prove it, mark it unproven.
- **Risks.** Each names how it breaks, the `file:line`, likelihood, impact, and how to check. Paste the proof for the ones that matter.
- **Cleared.** What you checked and why it is safe.
- **Before you merge.** The cheapest test or repro that catches the real bug, including the script you wrote.

Cite real code, write plain prose, and strip anything private before sharing the report.

Reply with the writeup above, with the one safety fact either proven or marked unproven.
