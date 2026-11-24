---
name: grilling
description: Grill the user relentlessly about a plan, decision, or idea. Use when the user wants to stress-test their thinking, or uses any 'grill' trigger phrases.
---

Interview the user relentlessly until you reach a shared understanding. Map the conversation as a **design tree**, where every decision branches into the decisions that depend on it.

Work the tree in **rounds**. The **frontier** is every decision whose prerequisites are already settled, meaning the questions you can ask _now_ without guessing at answers you have not heard yet. Ask the whole frontier in one round, number each question, and give your recommended answer. Then wait for the user's answers before starting the next round.

Format each round like this:

```markdown
**Q1. <question title>:** <question body, possibly multiple paragraphs, including multiple choices>

Recommended: <your recommended answer>

---

**Q2. <question title>:** <question body, possibly multiple paragraphs, including multiple choices>

Recommended: <your recommended answer>
```

Word each question so "yes" accepts your recommended answer.

Each round the user answers reshapes the tree, because settled decisions push the frontier outward and unblock questions that depended on them. Recompute the frontier and ask the next round. A question whose answer depends on another question still open in this round belongs to a _later_ round, not this one.

Finding _facts_ is your job, never the user's. When a frontier question needs a fact from the environment (filesystem, tools, or codebase), dispatch a sub-agent with a fresh context window to find it instead of asking the user for anything you can look up yourself. Do not block on that lookup. A running exploration is an unsettled prerequisite, so only the questions downstream of it wait for the sub-agent to report; ask the rest of the frontier now. The _decisions_ belong to the user, so put each one to them and wait.

The session is done when the frontier is empty, with every branch of the design tree visited and nothing left silently assumed. Do not act on the plan until the user confirms you have reached a shared understanding.
