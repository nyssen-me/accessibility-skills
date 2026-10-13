# Accessibility skills

Personal [Claude Code skills](https://docs.claude.com/en/docs/claude-code/skills) for accessibility work. They work in any project.

| Skill | What it does |
|---|---|
| [a11y-review](a11y-review/SKILL.md) | Reviews templates, CSS, JavaScript and content against WCAG 2.2 AA and the project's own rules, and reports the findings like a professional audit. |
| [contrast-check](contrast-check/SKILL.md) | Checks colour contrast in a site's CSS in every theme (light, dark, system or switcher), with a PowerShell script that resolves CSS custom properties. |

## Install

Claude Code loads personal skills from `~/.claude/skills/`, so this repo lives in that folder.

That folder usually exists already, holding a `synced/` folder that this repo ignores. Set it up like this:

```
cd ~/.claude/skills
git init -b main
git remote add origin https://github.com/nyssen-me/accessibility-skills.git
git pull origin main
```

The contrast check needs PowerShell. Windows PowerShell 5.1 is built into Windows; on macOS and Linux, install PowerShell 7 (`pwsh`).

## Use

In Claude Code, in any project:

- `/a11y-review`: reviews uncommitted changes.
- `/a11y-review all`, `/a11y-review about`, `/a11y-review path/to/file`: reviews everything, one page, or one file or folder.
- `/contrast-check`: checks the whole theme.
- `/contrast-check accent-color bg-color`: checks one pair.

Claude also uses the skills on its own when you ask about accessibility or contrast.

## Project settings

The skills are generic. Each project's details go in its own docs: an "Accessibility review" section in `docs/accessibility.md`, linked from `CLAUDE.md`. If a project has no such section, `a11y-review` offers to write one. Template:

```markdown
## Accessibility review

### Where things are
Templates, CSS source, JavaScript, content and its format.

### What to skip
Framework core, vendor code, build output, old reference files.

### Rendered site
Local URL or dev server command.

### Existing conventions
Hidden-text class, global focus style, reduced-motion rules, theme switcher,
heading level of the page title, root font size.

### Contrast check settings
The full contrast.ps1 command: -Css entry stylesheet, plus -DarkSelectors and
-TokensOnly if needed.
```
