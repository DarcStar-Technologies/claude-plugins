---
name: example-skill
description: Reference skill showing the skill layout. Explains how to produce a friendly localized greeting. Use when the user asks for a greeting in a specific language.
---

# Example Skill

This skill demonstrates the structure of a plugin skill: a directory under
`skills/` containing a `SKILL.md` with `name` and `description` frontmatter. The
`description` is what Claude reads to decide when to invoke the skill, so make it
specific about *when* to use it.

## What this skill does

Produce a short, friendly greeting in the language the user requests.

## How to use it

1. Determine the target language from the user's request (default: English).
2. Produce a one-line greeting in that language.
3. If the language is unknown to you, say so plainly rather than guessing.

## Notes for authors

- Keep `SKILL.md` focused. If a skill needs large reference material or scripts,
  add them as sibling files in this directory and link to them from here so they
  are loaded only when needed.
- A skill is for knowledge and model-invoked capability. If the task is fully
  deterministic, prefer a script in the plugin's `scripts/` directory instead.
