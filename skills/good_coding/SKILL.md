---
name: good-coding
description: >
  Use this skill whenever the user wants to write new code, update or modify
  existing code, fix bugs, refactor, add features, implement algorithms, or
  produce any source file in any language. Also triggers for: removing stale or
  legacy code ("clean up", "remove dead code", "delete deprecated X", "strip
  legacy flag"), and for keeping documentation in sync with code changes
  ("update the doc", "fix the comment", "update README", "sync the docstring").
  Trigger phrases include: "write a function", "implement X", "add a method",
  "update this file", "fix this bug", "refactor", "make X do Y", "remove unused
  Y", "clean up Z". Also triggers when the user pastes code and asks you to
  change, extend, or clean it. Use even for short snippets -- if the deliverable
  is code or code-adjacent documentation, use this skill.
---

# Coding Skill

Produces correct, idiomatic, production-quality code. Handles greenfield code,
modifications to existing code, removal of stale/legacy code, and keeping
documentation synchronized with code changes.

---

## Workflow

### 1. Understand Before Writing

Read all relevant context before touching any file:

- If files are uploaded or referenced, read them fully.
- Identify the language, framework, and style conventions already in use.
- For modifications, understand the full scope of what changes — not just the
  immediate edit site, but callers, types, tests, and headers that may be
  affected.
- Clarify ambiguous requirements before writing. One focused question beats
  writing the wrong thing.

### 2. Plan the Change

For non-trivial tasks, briefly outline the approach before writing code:

- What will be created or changed, and why.
- Any non-obvious design decisions or tradeoffs.
- Files that will be touched.

Skip the outline for small, obvious edits (e.g., rename a variable, fix a typo).

### 3. Write the Code

**Correctness first.** The code must actually work. Think through edge cases,
boundary conditions, and error paths before settling on an implementation.

**Match the existing style.** Adopt the conventions already present:
- Naming style (snake_case, camelCase, PascalCase)
- Brace style, indent width, line length
- Comment density and style
- Error handling patterns

**No placeholder filler.** Never write `// TODO: implement this` or
`pass` in a function body unless the user explicitly asked for a stub.
Deliver the real implementation.

**Complete changes only.** When modifying a file, output the entire modified
file (or the full functions being changed) — not a fragment with surrounding
context omitted. The user should be able to apply the output directly.

**Headers and imports.** Add any necessary includes, imports, or forward
declarations. Remove unused ones if cleaning up the surrounding code.

### 4. Language-Specific Standards

#### C++ (primary)
- Use modern C++ (C++17/20 where appropriate): structured bindings, `if
  constexpr`, ranges, `std::optional`, `std::variant`, `std::string_view`.
- Prefer `const` correctness throughout.
- Prefer references over raw pointers; use smart pointers (`unique_ptr`,
  `shared_ptr`) when ownership is explicit. Avoid raw owning pointers.
- Mark functions `noexcept` when they genuinely cannot throw.
- Follow RAII. No manual `new`/`delete` unless interfacing with a C API.
- Use `[[nodiscard]]` on functions whose return value must not be ignored.
- Thread safety: document it. Use `std::mutex`, `std::atomic`, or TBB
  primitives as appropriate; prefer lock-free where the pattern is clear.
- Template code: keep instantiations in headers or explicit; add `static_assert`
  to catch bad instantiations early.

#### Python
- Follow PEP 8. Use type hints for all function signatures.
- Prefer dataclasses or Pydantic models over raw dicts for structured data.
- Use `pathlib.Path` over `os.path`.
- Context managers (`with`) for resources.
- f-strings for formatting.

#### TypeScript / JavaScript
- Prefer `const`; avoid `var`.
- Use strict TypeScript (`"strict": true`). No `any` unless unavoidable.
- Async/await over raw promises.
- Destructuring, optional chaining, nullish coalescing.

#### General
- Fail loudly on invalid inputs (assertions, exceptions, or early returns with
  clear error messages) rather than silently returning a wrong value.
- Prefer pure functions and minimal side effects where practical.
- Short functions with a single clear responsibility.

### 5. Testing Considerations

If the codebase has tests, new code should be testable. When asked to write
tests, or when it's clearly expected:
- Cover the happy path, edge cases, and error cases.
- Use the test framework already present in the codebase.
- Test behavior, not implementation details.

If no test is requested but the change is risky or non-obvious, mention what
a test would check.

### 6. Documentation

Add comments where they add value — explain *why*, not *what*:

```cpp
// Snap to the nearer lane endpoint when arc-range inversion is detected;
// the geometric projection is correct but semantically wrong for U-shaped paths.
```

Not:

```cpp
// Check if start > end
if (start > end) { ... }
```

Public API functions get a doc comment (Doxygen, docstring, JSDoc) unless the
name is completely self-explanatory.

### 7. Cleanup: Removing Stale and Legacy Code

Triggered by: "remove dead code", "delete deprecated X", "clean up legacy Y",
"strip the feature flag", "remove the old path", etc.

**Identify what is safe to delete.**
- Confirm the code is genuinely unreachable or superseded -- trace callers,
  check feature flags, verify no external consumers (exported symbols, public
  APIs, serialized proto fields) depend on it.
- If unsure, ask before deleting. A wrong deletion is worse than leaving cruft.

**Delete completely, not partially.**
- Remove the dead function/class/variable AND its declaration, forward
  declaration, and any include/import that existed solely for it.
- Remove associated tests that only covered the deleted code path.
- Remove now-dead branches in call sites (e.g., an `if (legacy_flag)` block
  where the flag is gone).

**Do not ghost-comment.** Never replace deleted code with `// removed` or
`// legacy -- no longer used`. Just delete it. Version control is the history.

**Flag ripple effects.** If deleting X reveals that Y is now also dead, call
it out. Don't silently expand the deletion scope beyond what was asked, but
do surface the finding.

**Cleanup checklist before delivery:**
- [ ] Declaration removed (header / interface file)
- [ ] Definition removed (source / impl file)
- [ ] Call sites cleaned up (dead branches, now-unnecessary guards)
- [ ] Imports/includes that only served the deleted code removed
- [ ] Associated tests removed or updated
- [ ] No dangling references remain (search for the symbol name)

---

### 8. Documentation Sync

After any code change -- and explicitly when asked to "update the doc",
"fix the comment", or "sync the README" -- update all documentation that
describes the changed code.

**What to update:**

| Changed                        | Update                                      |
|-------------------------------|---------------------------------------------|
| Function signature             | Doxygen / docstring / JSDoc params & return |
| Behavior or algorithm          | Inline comments explaining the why          |
| Public API added or removed    | README / API reference section              |
| Config or flag added/removed   | README, config reference, usage examples    |
| Deprecated path removed        | Changelog entry (if project uses one)       |
| File moved or renamed          | Any cross-references in other files         |

**Rules:**
- Doc comments describe the *current* behavior -- not what the function used
  to do, not what was planned. If the old comment no longer matches, rewrite
  it entirely, not with an appended note.
- Remove doc comments for deleted code. A comment referencing a deleted
  function is misinformation.
- Keep it concise. A one-line docstring that is accurate beats a paragraph
  that is 80% stale.
- If the user only asked to update code (not docs), still update inline
  comments that are now wrong, and call out any higher-level docs (README,
  API reference) that need manual attention.

---

### 9. Delivery

- Output code in fenced code blocks with the language tag.
- For multi-file changes, one code block per file with the file path as a
  header or comment at the top.
- After the code, give a brief summary of what changed and why — 2-5 sentences,
  no padding.
- If there are follow-on considerations (e.g., a header that also needs
  updating, a test to write, a config to change), call them out explicitly.

---

## Common Pitfalls to Avoid

- **Partial output**: never truncate a function body with `// ... rest unchanged`.
  Output the complete function.
- **Silent wrong defaults**: if a parameter's default value matters, pick the
  right one -- don't guess.
- **Over-engineering**: solve the stated problem. Don't add abstractions,
  generics, or plugin systems unless asked.
- **Under-engineering**: don't return a hardcoded value or skip error handling
  to keep the code short. It has to work.
- **Changing unrelated code**: confine edits to what was asked. Don't reformat
  surrounding lines or rename things that weren't part of the request.
- **Partial cleanup**: don't remove a function body but leave the declaration,
  or remove an implementation but leave the test that covers it. Delete fully.
- **Stale doc comments**: after any code change, never leave a comment that
  describes old behavior. Rewrite or remove it.
- **Assuming something is dead**: before deleting, verify no callers exist.
  One grep is worth more than one assumption.