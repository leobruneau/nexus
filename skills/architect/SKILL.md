---
name: architect
description: Sketch types, signatures, and module structure before writing code. Use for /architect or non-trivial work where jumping to code risks locking in the wrong shape.
disable-model-invocation: true
---

# Architect

Before writing code, trace every system the change touches. Sketch two different shapes for it (types, signatures, module boundaries) and pick the one where each piece of state has one owner, each task has one way to do it, and callers need to know least. Redesign instead of patching if workarounds repeat.

For a large or contested design, use the parallel subagent design exploration in [DESIGN-IT-TWICE.md](../codebase-design/DESIGN-IT-TWICE.md) instead of sketching alone.
