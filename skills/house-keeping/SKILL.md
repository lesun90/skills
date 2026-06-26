---
name: house-keeping
description: >
  Use when preparing code for commit, finishing a feature, or doing a cleanup
  pass on existing code. Triggers for: "clean up before committing", "tidy the
  code", "remove dead code", "housekeeping", "prep for PR", "code cleanup",
  "remove stale code", "make code consistent", "follow standard practices",
  "remove unused X", "update outdated Y", "cleanup project", "remove dangling
  packages", "remove unused dependencies", "clean up services", "ensure repo
  works for new users", "fresh clone test", "README check", "onboarding
  readiness", "organize files", "restructure docs", "project structure cleanup".
  Also use when the user asks to review changes before committing and wants to
  make sure the code is clean, consistent, and follows conventions — even if
  they don't say "housekeeping" explicitly. The goal is always: improve quality
  without changing behavior.
---

# House-Keeping

A disciplined pre-commit cleanup pass. The job is to improve code quality
without touching logic — the diff should show only polish, never behavior
change.

**Core rule:** If a thought starts with "while I'm in here, I should also fix..."
— stop. Finish the cleanup, commit it, then handle the fix separately.

---

## Step 0: Establish a Baseline

Before changing anything, run the full test suite and note the results.
You'll run it again at the end to confirm nothing changed.

```bash
# Whatever the project uses:
pytest / npm test / go test ./... / cargo test / make test
```

If there are no tests, note that — and don't skip the final check either
(manual smoke test or linter pass).

---

## The Checklist

Work through these in order. After each category, tests should still pass.

### 1. Remove Stale Code

Dead code is noise that future readers have to mentally skip over.

- [ ] **Unused imports/requires** — delete them
- [ ] **Unused variables and parameters** — delete or rename to `_` where
  the language convention requires a placeholder
- [ ] **Dead functions/classes** — functions with no callers, classes with
  no instantiations (verify with grep before removing — see "Safe Removal" below)
- [ ] **Commented-out code blocks** — if it's been commented out, it's been
  deleted; version control has the history, no need to keep a graveyard
- [ ] **Stale TODO/FIXME comments** — if resolved, remove; if still valid
  but out of scope for this pass, leave them
- [ ] **Unused files** — verify with grep before deleting

### 2. Consistency

Inconsistency forces the reader to hold two mental models at once.

- [ ] **Naming conventions** — align with the project's established style
  (snake_case, camelCase, etc.). Check CLAUDE.md or a style guide if present.
- [ ] **Idiom consistency** — if the codebase uses `Array.from(set)` in one
  place and `[...set]` in another, pick one and apply it uniformly
- [ ] **Error handling patterns** — consistent with the rest of the codebase
  (throw vs return error, checked vs unchecked exceptions, etc.)
- [ ] **Import organization** — group and order imports the way the project does
  (stdlib first, then third-party, then local — or whatever the project does)

### 3. Documentation Sync

Stale docs are worse than no docs — they actively mislead.

- [ ] **Docstrings / JSDoc / Doxygen** — do they still match the actual
  function signature and behavior? Rewrite if not (don't append a note)
- [ ] **Inline comments** — remove comments that explain *what* the code
  does (the code does that); keep or add comments that explain *why*
- [ ] **References to old names** — old function names, removed parameters,
  previous behavior — delete or update them

### 4. Standard Practices

- [ ] **Debug artifacts removed** — `console.log`, `print()`, `debugger`,
  `pdb.set_trace()`, `TODO: remove this`, etc.
- [ ] **No deprecated API usage** — check against the language/framework
  migration guide; update call sites if the new API is a straightforward swap
- [ ] **Magic numbers extracted** — if a literal appears more than once and
  has semantic meaning, extract it as a named constant
- [ ] **No hardcoded secrets or env-specific values** — these belong in
  config files or environment variables

---

## Step 5: Confirm No Behavior Change

Re-run the exact same test suite from Step 0. Results must be identical.

If something fails that passed before, you introduced a regression — find
and fix it before committing.

---

## Safe Removal: Verify Before Deleting

Before removing anything, confirm it's genuinely unused. Dynamic dispatch,
reflection, and string-based lookups can reference symbols that look unused
in a static scan.

```bash
# Search for the symbol name
grep -r "function_name" .
grep -r "ClassName" . --include="*.ts"

# Also check string references (dynamic dispatch, eval, getattr, etc.)
grep -r '"function_name"' .
grep -r "'function_name'" .
```

If you're not sure — don't delete. Flag it and let the author decide.

---

## Project-Level Housekeeping

When the scope is the whole repo — not just a single file or feature — extend
the checklist with these passes. Do each as its own commit.

### 5. Dependency Cleanup

Dangling packages slow installs, introduce security surface, and mislead the
next developer about what the project actually needs.

- [ ] **List installed vs. declared packages** — compare `package.json` /
  `requirements.txt` / `go.mod` / `Cargo.toml` against what the code actually
  imports
- [ ] **Remove unused packages** — uninstall and remove from the manifest;
  run tests to confirm nothing breaks
- [ ] **Flag outdated packages** — run the appropriate audit tool and note
  major-version upgrades that need testing:

  ```bash
  npm outdated / pip list --outdated / go list -m -u all / cargo outdated
  ```

- [ ] **Remove lock-file artifacts** — delete leftover entries for packages
  you just removed; commit the updated lock file alongside the manifest change
- [ ] **Audit for security issues** — run `npm audit` / `pip-audit` /
  `cargo audit` and fix or document any high-severity findings

### 6. Service and Configuration Cleanup

Stale services and config drift are invisible until a new person tries to run
the project.

- [ ] **Remove unused services** — Docker Compose services, cloud functions,
  background workers, cron jobs that are no longer referenced
- [ ] **Remove orphaned config files** — `.env.example` keys with no
  corresponding code, Nginx vhosts for domains that no longer exist, CI job
  steps that build artifacts nobody consumes
- [ ] **Reconcile `.env.example`** — every key must map to code that reads it;
  every key the code reads must be in `.env.example` with a safe placeholder
- [ ] **Remove dead feature flags** — flags that are always-on or always-off;
  inline the enabled branch and delete the flag infrastructure

### 7. Fresh-Clone Readiness

The test: someone clones the repo cold and follows the README. Do they succeed
without asking a question?

**Run the README yourself:**

```bash
# Start from a clean environment simulation
git clone <repo> /tmp/test-clone && cd /tmp/test-clone
# Follow every step in the README literally — no muscle memory shortcuts
```

Check each step:

- [ ] **Prerequisites section is accurate** — correct runtime versions, system
  tools, and environment setup; remove tools that are no longer needed
- [ ] **Install step works** — `npm install` / `pip install -r requirements.txt`
  / `go mod download` completes without errors
- [ ] **Environment setup is complete** — copying `.env.example` → `.env` and
  filling in the documented placeholders is sufficient to start the app
- [ ] **Start command works** — the README's run command actually starts the
  app with no extra undocumented steps
- [ ] **No "it works on my machine" state** — nothing depends on a globally
  installed tool, a pre-created directory, or a locally populated database that
  isn't covered by the README

Fix any step that fails. Update the README to match reality, not the other way
around.

### 8. File and Document Organization

Disorganized trees force every contributor to re-discover the structure.

- [ ] **Remove empty directories** — unless they hold a `.gitkeep` for a
  required but untracked path (document why in the README)
- [ ] **Co-locate related files** — tests next to source, config next to the
  service that reads it, migrations next to the schema
- [ ] **Flatten gratuitous nesting** — a directory with one file is usually
  better as just that file; three levels of `utils/helpers/common/` is noise
- [ ] **Consistent naming** — pick one convention (`kebab-case`, `snake_case`,
  `PascalCase`) for files in each layer and apply it uniformly
- [ ] **Prune doc rot** — delete or archive docs that describe a removed
  feature, an old architecture, or a process the team no longer follows
- [ ] **README is the entry point** — the root README should link to deeper
  docs, not duplicate them; deeper docs should be findable from the README
  without searching the repo

After reorganizing files, run the full test suite — path-dependent imports
break silently.

---

## Red Flags: You've Left Housekeeping

Stop and commit what you have if you catch yourself doing any of these:

| You're doing this... | This is... |
|---|---|
| Adding error handling for a new case | Feature work |
| Changing a function signature | Feature work |
| Fixing a bug you noticed | Bug fix |
| Adding tests for untested paths | Test work |
| "Improving" an algorithm | Refactoring (separate commit) |
| Updating a dep to get a new feature | Feature work |

The right move: `git stash`, commit the housekeeping, `git stash pop`,
then continue with the other work.

---

## Commit Guidance

Housekeeping changes belong in their own commit(s), separate from feature or
fix changes. This keeps history readable and makes `git bisect` reliable.

Use `chore:` prefix (conventional commits):

```bash
git commit -m "chore: remove unused imports and dead helpers"
git commit -m "chore: sync docstrings with current signatures"
git commit -m "chore: replace magic numbers with named constants"
```

One commit per logical category is fine. Don't mix housekeeping with feature
changes in the same commit even if the feature change is small.

---

## Common Mistakes

**Removing "obviously unused" code without grepping** — dynamic dispatch
bites back. Always grep.

**Deleting a comment that seems redundant** — read it first. Old comments
sometimes document non-obvious invariants or workarounds for specific bugs.
If the comment is genuinely stale, delete it. If it's explaining a "why",
keep or rewrite it to be accurate.

**Reformatting an entire file when only touching a few lines** — this
creates a noisy diff that obscures the real changes. Either run the auto-
formatter on the whole project (separate commit) or limit your edits to the
lines you're already touching.

**Updating a docstring that "seems wrong"** — verify the *code* behavior
first. The doc might be right and the code might be the bug.

**Merging housekeeping into a feature commit "just this once"** — the
reviewer now has to untangle which changes are functional and which are
cosmetic. Keep them separate.
