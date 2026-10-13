---
name: a11y-review
description: Accessibility review of a website's templates, CSS, JavaScript and content against WCAG 2.2 AA and the project's own accessibility rules, reported like a professional audit. Use when the user asks for an accessibility review or audit, asks whether a change is accessible, or before committing front-end changes.
argument-hint: "[file | folder | page URL or slug | all]"
---

# Accessibility review

Find WCAG 2.2 AA failures and anything that makes the site harder to use, even if it technically passes. Hold it to the standard of a professional audit: specific, accurate, no padding and no false alarms.

Report only. Change files only after the user says which findings to fix.

## 1. Load the project's context

Read the project's `CLAUDE.md` and the accessibility docs it links to (often `docs/accessibility.md`). Look for:

- **Standard and rules:** the target (WCAG 2.2 AA unless stated) and the project's own rules, such as colour rules, preferred patterns and things it forbids, like overlays.
- **Where things are:** templates, CSS source, inline or separate JavaScript, page content and its format.
- **What to skip:** framework core, vendor code, build output, minified files, old reference files.
- **How to see the rendered site:** a local URL or dev server command.
- **Existing conventions:** the hidden-text class, the global focus style, reduced-motion handling, how the theme switcher works, which elements the layout already provides (skip link, `<h1>`, landmarks).
- **Contrast check settings:** the command for the contrast-check skill.

If something is missing, work it out from the code. At the end, offer to write what you learned into a short "Accessibility review" section in the project's docs, so the next review starts faster. Use the same headings as above.

## 2. Work out the scope

From the argument:

- **None:** uncommitted changes (`git status --porcelain`, `git diff HEAD`) to front-end files: templates, HTML, CSS, JavaScript and content. If nothing has changed, review the last commit (`git show --stat HEAD`) and say so.
- **File or folder:** that path.
- **Page URL or slug:** the rendered page, plus the templates, CSS and content that build it.
- **`all`:** every template, stylesheet, script and content page, skipping what the project docs say to skip.

Always skip vendor code, dependencies (`node_modules`, `vendor`), framework core and build output, unless the user asks for them. Tell the user the scope before starting a review that covers many files.

## 3. Read with enough context

A file alone rarely shows the whole picture.

- **Templates:** read the layout and wrapper templates (head, header, footer, base layout) before judging landmarks, headings, skip links or focus order. A partial only adds part of the page.
- **CSS:** find which templates use the selectors you are reviewing. Read the global styles that components inherit, such as the focus style, the hidden-text class and reduced-motion rules.
- **JavaScript:** check what it changes in the DOM and whether ARIA state and focus follow.
- **Content:** find out which heading level the template gives the page title, so you know where content headings should start.

## 4. Check the rendered page

Templates and content combine at runtime. If the project has a local URL or a running dev server, fetch the pages in scope:

```
curl -s <local-url>/<page>
```

If it can't connect, say so and continue with the code alone.

In the HTML, check:
- `<title>` and `lang`
- exactly one `<h1>`, and the order of all headings
- landmarks
- duplicate `id`s and broken ID references
- alt text
- link and button names

## 5. Run the contrast check

If CSS, colours or inline styles are in scope, use the **contrast-check** skill with the project's settings. Report its FAIL lines and theme problems. Look at the code behind each CHECK line, and report only the ones that actually fail.

## 6. Go through the checklist

Read [checklist.md](checklist.md) and check every item that applies to the code in scope. Also apply the project's own rules from step 1. Look for problems the checklist doesn't list too: it's a floor, not the limit.

Before reporting something, confirm it in the code. For example:
- an `aria-label` that looks wrong may be overridden
- a missing focus style may come from a global rule
- a "missing" heading may be in the layout template

Don't report redundant-but-harmless code (such as `role="main"` on `<main>`) as a failure. At most, list it as tidy-up.

## 7. Report

Use this structure:

### Findings

Group by severity, most severe first:

- **Blocker:** fails AA and stops someone from completing a task or reaching content, for example a keyboard trap, an unlabelled control or invisible text.
- **Fails AA:** a WCAG 2.2 AA failure that doesn't block.
- **Improvement:** passes AA but still makes the site harder to use, or breaks a project rule.

Format each finding as:

```
**[file:42](path/to/file#L42)** – What is wrong, in one sentence.
- WCAG: 2.4.4 Link Purpose (In Context), or "Project rule" / "Best practice"
- Affects: who, and how, for example "screen reader users hear 'Home' but see 'Nyssen'"
- Fix: the concrete change, with a short code snippet if it helps
```

Group repeats of the same problem into one finding and list all their locations.

### Needs manual testing

List only what static review can't confirm for this scope, and say exactly what to check. For example: "Turn on NVDA in Firefox and press the theme switcher. It should announce 'Dark theme, toggle button, pressed'." Relevant checks include:

- NVDA or JAWS with Firefox or Chrome, VoiceOver with Safari (macOS and iOS), and TalkBack with Chrome
- keyboard-only use
- 200% and 400% zoom, and reflow at 320px wide
- a text-spacing bookmarklet
- Windows contrast themes (forced colours)
- reduced motion
- every theme the site has

### Checked and passed

One or two lines on what you checked that was fine, so the user knows the coverage.

Then ask which findings to fix. When fixing, follow the project's `CLAUDE.md` conventions: build steps, deployment notes, files not to touch, and how to report changed files.
