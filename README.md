# skills

A personal skill library for AI coding agents. Skills are reference guides that teach agents proven techniques, patterns, and workflows. This repo ships an `install` script that copies skills into any project without committing them.

## Bootstrap (once per machine)

```bash
git clone git@github.com:<you>/skills.git ~/skills
```

## Install into a project (per project)

From any project repo root:

```bash
~/skills/install           # all agents (default)
~/skills/install claude    # Claude Code only
~/skills/install codex     # Codex only
```

The script self-updates from git, then copies skills into agent-native paths and records exclusions in `.git/info/exclude`.

## What install does

| Output | Agent | Purpose |
|--------|-------|---------|
| `.claude/skills/<skill-name>/` | Claude Code | Discovered via the `Skill` tool |
| `.agents/skills/<skill-name>/` | Codex | Discovered automatically at session start |
| `.git/info/exclude` entries | — | Keeps generated files out of git without touching `.gitignore` |

Re-running is safe — all operations are idempotent.

## Skills

| Skill | What it covers |
|-------|---------------|
| `brainstorming` | Structured ideation before starting implementation |
| `dispatching-parallel-agents` | Running subagents concurrently for independent tasks |
| `executing-plans` | Following implementation plans task-by-task with review |
| `finishing-a-development-branch` | Pre-PR checklist for branches |
| `receiving-code-review` | How to respond to and act on code review feedback |
| `requesting-code-review` | How to request and frame a code review |
| `subagent-driven-development` | Full development workflow using subagents |
| `systematic-debugging` | Root-cause tracing, condition-based waiting, defense-in-depth |
| `test-driven-development` | RED-GREEN-REFACTOR discipline with anti-rationalization guardrails |
| `using-git-worktrees` | Parallel work across branches without stashing |
| `using-superpowers` | How agents discover and invoke skills |
| `verification-before-completion` | Checklist before declaring any task done |
| `writing-skills` | TDD-based process for creating and testing new skills |

## Repo layout

```
skills/
  install              # installer script
  skills/
    <skill-name>/
      SKILL.md         # main reference (required)
      ...              # supporting files (optional)
  tests/
    run_tests.sh       # test suite for the installer
  design_doc.md        # design decisions for the installer
```

## Running tests

```bash
bash tests/run_tests.sh
```

## Adding a skill

1. Create `skills/<skill-name>/SKILL.md` with YAML frontmatter (`name`, `description`)
2. Follow the `writing-skills` skill for the full TDD-based authoring process
3. Run `~/skills/install` in any project to pick up the new skill
