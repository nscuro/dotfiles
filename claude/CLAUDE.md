## General

* Prefer simple, pragmatic solutions over complex, supposedly future-proof ones. Add a rule, abstraction, or test when something actually goes wrong, not speculatively.
* Prefer common, industry standard solutions and procedures over bespoke ones.
* Apply a high standard for systems design, security, and maintainability.
* Never create git commits. Make the changes, stage them if useful, then stop and say what is ready.
* Never create issues, PRs, or comments on my behalf without explicit instruction.
* Verify claims against the code before asserting them. Give counts, `file:line`, or say the signal is weak. Never present a convention as established from memory or plausibility.
* When editing my files, match the surrounding voice and format. Do not import a different style.

## Communication style

* Default to the shortest output that answers. Reviews, plans and explanations you're asked for run as long as they need. Cut prose, not content.
* Be direct. Omit phrases like "sharp observation" and "good instinct" when responding to me. Acknowledge, don't ego-stroke.
* When asked for feedback, be objective and critical. Do not sugarcoat things. Do not try to prove that an existing solution is fit for purpose. Think outside the box and consider alternative solutions.

## Scope and approval

* A question is not a work order. Answer it, don't edit files or implement.
* Implementation needs an explicit go-ahead ("do it", "implement", approved plan). Otherwise propose and stop.
* Reading, grepping, and running tests never need asking. Me agreeing with your diagnosis is not approval.

## Coding Preferences

### Precedence

Defaults. Repo conventions (`AGENTS.md`, `CLAUDE.md`, rules files) override them, existing code does not. Code predating a convention is no reason to keep writing it that way. Apply to code you are already changing. NEVER MASS-CONVERT UNTOUCHED CODE.

### Test-Driven Development

Red-green-refactor, one behavior per cycle: write the failing test, run it, confirm it fails for the intended reason (not a compile error or typo), write the minimum code to pass, run again, refactor only while green.

* Never write the implementation first. Never report a cycle you did not run.
* When test fails, fix the code. Change the test only if it encodes the wrong expectation. Never paste actual output into the expected value.
* Skip only for changes with no behavior, i.e. renames, formatting, comments, config.

### Testing

* Test the outermost layer that is still fast and deterministic. It covers wiring, serialization and authorization that isolated tests skip, and survives refactoring below (think "testing trophy", not pyramid).
* Drop a layer only for what the top cannot reach: error paths, boundaries, concurrency.
* Never duplicate coverage a higher-layer test already has. Extend that test instead.
* Unit-test pure functions with wide input spaces (parsers, converters, comparators). Parameterize them.

### Comments and Docstrings

Comments are a liability: nothing checks them against the code, so they drift and mislead.
Write none unless a competent reader would misread the code, or "fix" it into a bug, without one.
Try better names, types, or a test first.

* Keep it to the non-obvious why, in one line. Never restate the code, narrate the change, or cite the task, rules file, or benchmark behind it. No `TODO` markers unless asked.
* Docstrings only on public API, and only for what the signature does not say.
* When you change code, fix or delete the comments it invalidates. Never delete comments you did not write unless asked.
* Write comments with the `unslop` skill.

## Tools

* When the JetBrains MCP server is available, prefer it over shell equivalents: `search_symbol` / `get_symbol_info` for navigation, `rename_refactoring` for renames, `get_file_problems` before calling a change done. Fall back to `grep` / `sed` when it is not.
* In Java projects, use the `javadocs` MCP server to inspect third-party APIs (javadoc, sources, available versions). Never extract or read JARs from the local Maven repository (`~/.m2`), and never recall an API signature from memory when the server can answer.
* Always invoke `snpm` instead of `npm`. `snpm` runs `npm` in a sandbox. Bare `npm` is blocked.
