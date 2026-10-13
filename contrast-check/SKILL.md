---
name: contrast-check
description: Checks WCAG 2.2 AA colour contrast in a site's CSS, in both light and dark themes, using a script that reads the stylesheets and resolves CSS custom properties. Use when CSS colours, theme variables or a theme switcher change, when the user asks about contrast or whether a colour combination passes, or as part of an accessibility review.
argument-hint: "[colour colour | css path]"
---

# Contrast check

[contrast.ps1](contrast.ps1), in this skill's folder, does the maths, so ratios are exact and repeatable. Always run it; never estimate contrast by eye.

It needs PowerShell: Windows PowerShell 5.1 is built into Windows, and on macOS or Linux use `pwsh` (PowerShell 7).

## 1. Find the project's settings

Look in the project's `CLAUDE.md` and the accessibility docs it links to (often `docs/accessibility.md`) for a contrast check command or settings. They give:
- the entry stylesheet
- the dark theme selectors
- whether components may only use theme variables

If there are none, work them out:

- **Stylesheet:** the CSS the templates actually load, normally the entry file that `@import`s the rest. Use the source CSS, not minified output. The script can't read Sass, Less, Tailwind classes or CSS-in-JS. For those, check the compiled CSS if there is any, or single pairs with `-Fg`/`-Bg`.
- **Dark theme:** search the CSS for `prefers-color-scheme`, `data-theme`, `.dark` and `color-scheme`. Rules inside `@media (prefers-color-scheme: dark)` and selectors with the word "dark" in them are detected automatically. Pass `-DarkSelectors` for anything else, such as `[data-mode="night"]`.
- **Theme-variables-only rule:** add `-TokensOnly` if the project says components must use theme variables, never raw colours.

After the run, suggest saving the command in the project's accessibility docs, so later runs and other projects stay consistent.

## 2. Run it

From the project root:

```
powershell -NoProfile -ExecutionPolicy Bypass -File "<this skill's folder>/contrast.ps1" -Css path/to/style.css
```

This skill's folder is normally `~/.claude/skills/contrast-check`.

Options:

| Option | Use |
|---|---|
| `-Css a.css,b.css` | Files or folders. Files are followed through their local `@import`s. |
| `-DarkSelectors ':root[data-theme="dark"]'` | When automatic detection isn't enough |
| `-LightSelectors` | Where the default theme variables are defined. Default: `:root, html` |
| `-PageBg bg-color` | Page background, as a colour or a variable. Default: the `html`/`body` background, or white. |
| `-TokensOnly` | Treat palette variables and hardcoded colours as failures |
| `-Fg accent -Bg bg` | One pair. Takes variables (with `-Css`), hex without `#`, `rgb()`, `hsl()` or named colours. |
| `-All` | Also list the pairs that pass |

The argument tells you the mode:
- two colours: run `-Fg`/`-Bg`
- a path: use it as `-Css`
- nothing: run the full check with the project's settings

The script exits with code 1 if anything fails.

## 3. Read the results

- **Header:** the files read, the themes found (check these are right; if not, adjust the selectors and run again) and the page background.
- **1–2. Theme colours and pairs:** what each theme variable resolves to and how the pairs contrast. Palette pairs show which raw colours can never go together.
- **3. Colour pairs in CSS rules:** each `color`, `fill`, `stroke`, `border` and `outline`, checked in every theme the rule applies to. Text needs 4.5:1; everything else needs 3:1.
  - **FAIL:** the colour and the background are in the same rule, or it's a focus outline. This is a real failure.
  - **CHECK:** the background was assumed to be the page's. Find the real background in the CSS and templates (a parent element, a `:hover` rule, a base class) before deciding. A ratio of 1.00:1 almost always means the real background is set somewhere else.
- **4. Theme problems:**
  - **FAIL**
    - undefined variables, which make the browser ignore the declaration
    - dark theme definitions that differ, such as a `prefers-color-scheme` block and a switcher selector that set different values
    - with `-TokensOnly`, palette or hardcoded colours
  - **WARN:** colours that are the same in every theme. Make sure they work on each theme's background.

## 4. Report and fix

- **Report:** each FAIL and each CHECK you've confirmed, with `file:line`, the ratio in each theme, the WCAG criterion (1.4.3 text, 1.4.11 non-text, 2.4.7 focus visible) and a concrete fix.
- **Proposing colours:** check any proposed pair with `-Fg`/`-Bg` before suggesting it. Keep to the project's colour rules and theme variables.
- **Large text** (24px, or 18.66px bold) only needs 3:1. Check the computed `font-size`, which depends on the root font size, before relying on it.
- **Borders and outlines** only need 3:1 when they're the only thing showing a control, its state or focus. Decorative lines don't.
- **What the script can't see** (mention any that apply rather than assuming they pass):
  - inline styles and SVG file colours
  - images and gradients
  - translucent colours and `opacity`
  - `color-mix()`
  - text over images
  - Windows forced colours mode
- Don't change files unless the user asks. After a fix, run the script again to confirm.
