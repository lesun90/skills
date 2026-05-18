---
name: scaffolding
description: >
  Use this skill when the user types "/scaffolding" followed by a spec or design
  document (as a file path or uploaded file). Reads the spec, infers project
  structure, and generates a complete project scaffold in the current working
  directory: folder layout, README, design doc, decision log, and milestone
  progress tracker. Trigger on: "/scaffolding", "scaffold this spec",
  "create project structure from spec", "set up project from design doc",
  "scaffold from spec". Language-agnostic -- works for any project type
  (C++, Python, web, research, etc.). Always use this skill before writing any
  project boilerplate manually.
---

# Scaffolding Skill

Reads a spec or design document and generates a ready-to-use project workspace
in the current working directory. Output includes folder structure, docs, and
progress tracking -- no manual boilerplate needed.

---

## Invocation

```
/scaffolding <path-to-spec>
/scaffolding                  ← with an uploaded file attached
```

---

## Workflow

### Step 1 — Read the spec

**If a file path is given:**
```bash
cat <path>
```
For PDFs or DOCX, use `extract-text <path>` if available, otherwise read the
file-reading skill at `/mnt/skills/public/file-reading/SKILL.md` for the right
approach.

**If a file is uploaded:**
Check `/mnt/user-data/uploads/` for the file. Read it using the method
appropriate for its extension (see file-reading skill). Plain text and Markdown
files: `cat`. PDFs: `extract-text` or the pdf-reading skill.

---

### Step 2 — Extract key information

Scan the spec and extract the following. If a field is not explicit in the spec,
infer a reasonable value or leave it empty:

| Field | What to look for |
|---|---|
| `project_name` | Title, heading, or name of the system/product |
| `purpose` | One-paragraph summary of what the project does |
| `components` | Major modules, subsystems, or services mentioned |
| `tech_stack` | Languages, frameworks, build systems (if mentioned) |
| `milestones` | Phases, iterations, numbered goals, or deliverables |
| `open_questions` | TODOs, TBDs, unresolved decisions, risks flagged |

---

### Step 3 — Propose the scaffold tree

Before writing any files, print the proposed structure in chat:

```
<project_name>/
├── README.md
├── docs/
│   ├── spec.md
│   ├── design.md
│   ├── decisions.md
│   └── progress.md
├── <component-1>/
│   └── README.md
├── <component-2>/
│   └── README.md
└── ...
```

Then ask:

> "Does this structure look right? I'll create it in the current directory once
> you confirm."

Wait for confirmation before writing. If the user requests changes to the tree,
adjust and re-propose. Only proceed when approved.

---

### Step 4 — Write the scaffold

Create all files using `bash_tool`. Root directory is the current working
directory (`$(pwd)`). Use `mkdir -p` for nested paths.

#### `README.md`

```markdown
# <project_name>

<purpose — one concise paragraph from the spec>

## Components

<bullet list of components with one-line description each>

## Quick Start

_Fill in once environment and build steps are known._

## Docs

- [Spec](docs/spec.md)
- [Design](docs/design.md)
- [Decisions](docs/decisions.md)
- [Progress](docs/progress.md)
```

#### `docs/spec.md`

Copy the full spec content verbatim. If the spec was a file path, note the
original path at the top:

```markdown
<!-- Original spec: <path> -->
```

#### `docs/design.md`

Extract and reformat the architectural content from the spec:

```markdown
# Design

## Purpose

<one paragraph>

## Architecture

<component breakdown: what each component does, how they relate>

## Data Flow

<if described in spec; otherwise omit this section>

## Key Interfaces

<if described in spec; otherwise omit this section>
```

Keep this document factual and derived from the spec. Do not invent details.

#### `docs/decisions.md`

```markdown
# Decisions & Open Questions

Tracked design decisions and unresolved questions for <project_name>.

## Open Questions

<one item per open question or TBD extracted from the spec>
- [ ] <question>
- [ ] <question>

## Decisions Made

_None yet. Add resolved decisions here with rationale._
```

#### `docs/progress.md`

```markdown
# Progress

## Milestones

<one checkbox per milestone or phase extracted from the spec>
- [ ] <milestone 1>
- [ ] <milestone 2>
- [ ] ...

## Log

| Date | Update |
|------|--------|
| _Start_ | Project scaffold created |
```

#### Per-component `README.md`

For each component inferred from the spec, create `<component>/README.md`:

```markdown
# <Component Name>

## Purpose

<one paragraph: what this component does, extracted or inferred from spec>

## Interface

_Document public APIs, inputs/outputs, or entry points here._

## Dependencies

_List dependencies on other components or external systems here._

## Status

- [ ] Not started
```

Normalize component folder names to `kebab-case`.

---

### Step 5 — Source file stubs (conditional)

Only create source file stubs if the tech stack is unambiguous from the spec.

**C++ / Bazel:**
```
<component>/
├── BUILD
├── <component>.h
└── <component>.cc
```

**Python:**
```
<component>/
├── __init__.py
└── <component>.py
```

**Node.js / TypeScript:**
```
<component>/
├── package.json   (name only, no deps)
└── index.ts
```

If the stack is unclear or mixed, skip stubs and note in the summary.

---

### Step 6 — Print summary

After all files are written:

```
Scaffold created at ./<project_name>/

  README.md
  docs/spec.md
  docs/design.md
  docs/decisions.md
  docs/progress.md
  <component-1>/README.md
  <component-2>/README.md
  ...

Next steps:
  - Review docs/decisions.md for open questions to resolve
  - Fill in docs/design.md sections marked TBD
  - Update docs/progress.md as work proceeds
```

---

## Edge Cases

| Situation | Behavior |
|---|---|
| Spec has no clear project name | Use the filename (without extension) as the project name |
| No milestones in spec | Create `progress.md` with a single placeholder milestone |
| No components mentioned | Create a single `src/` folder with a README |
| Spec is very short (< 100 words) | Proceed but note in chat that the spec is sparse; scaffold will be minimal |
| Output directory already exists | Warn the user before writing; do not overwrite existing files |

---

## Key Principles

- **Never invent content.** Every line in the generated docs must trace back to
  the spec. If something is unknown, use a placeholder and say so.
- **Confirm before writing.** Always show the proposed tree and wait for
  approval.
- **Language-agnostic by default.** Only add source stubs when the tech stack
  is explicit.
- **Minimal and honest.** A sparse scaffold from a sparse spec is correct
  behavior, not a failure.
