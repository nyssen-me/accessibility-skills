# Accessibility checklist: WCAG 2.2 AA

Check only what applies to the code in scope. Numbers are WCAG 2.2 success criteria. Also apply the project's own rules from its docs, which can be stricter.

## Page structure

- [ ] `<html lang>` is set (3.1.1). Phrases in another language have their own `lang` (3.1.2).
- [ ] Each page has a unique, descriptive `<title>` (2.4.2).
- [ ] Landmarks:
  - one `<header>`, one `<main>` and one `<footer>`
  - each `<nav>` has a distinct label when there's more than one
  - no content outside a landmark (1.3.1, best practice)
- [ ] There's a skip link to the main content, and every template's `<main>` has the `id` it points to (2.4.1).
- [ ] One `<h1>`. Headings don't skip levels going down, and headings are never used just for styling (1.3.1, 2.4.6).
- [ ] Lists use `<ul>`/`<ol>`/`<dl>`. Groups of links are lists. Tables are only for data, with `<th>`, `scope` and a `<caption>` (1.3.1).
- [ ] No duplicate `id`s. Every `aria-labelledby`, `aria-describedby`, `aria-controls`, `for` and `href="#..."` points to an `id` that exists (1.3.1, 4.1.2).
- [ ] The DOM order matches the visual and reading order. Watch out for flex `order`, `row-reverse`, absolute positioning and grid placement (1.3.2, 2.4.3).
- [ ] Navigation stays in the same order on every page (3.2.3). The same thing is named the same way everywhere (3.2.4). If help or contact links appear on several pages, they are in the same place on each (3.2.6).
- [ ] There's more than one way to find pages: navigation plus search, a sitemap or links (2.4.5).

## Links and buttons

- [ ] `<a href>` for going somewhere, `<button type="button">` for doing something. No clickable `<div>`/`<span>`, and no `href="#"` or `javascript:` links (2.1.1, 4.1.2).
- [ ] Link text makes sense on its own or in its sentence. No "click here" or "read more" without context. The same text doesn't lead to different places (2.4.4).
- [ ] The accessible name contains the visible text, ideally at the start, so speech users can say what they see. An `aria-label` that replaces different visible text fails (2.5.3).
- [ ] Icon-only controls have a name: visually hidden text or `aria-label`, but not both, because `aria-label` overrides the text. Decorative SVGs have `aria-hidden="true" focusable="false"` (1.1.1, 4.1.2).
- [ ] State is exposed and kept up to date: `aria-pressed` for toggles, `aria-expanded` for disclosures, `aria-current="page"` for the current nav item. A toggle's name doesn't change when its state changes (4.1.2).
- [ ] Targets are at least 24 × 24 CSS px, or spaced so a 24px circle on each doesn't overlap another. Links inside sentences are exempt. Check icon buttons, toggles, close buttons, social links and pagination (2.5.8).
- [ ] External links and links to files (such as PDFs) say so if they behave differently. New windows are avoided, or announced if used (best practice).

## Keyboard and focus

- [ ] Everything works with the keyboard alone. No positive `tabindex`. No keyboard traps (2.1.1, 2.1.2).
- [ ] Focus is always visible:
  - nothing sets `outline: none`/`0` without an equally visible replacement
  - hover/focus rules don't make text and background the same colour
  - the indicator has 3:1 contrast against what's next to it (2.4.7, 1.4.11)
- [ ] Focus is never hidden behind sticky or fixed headers, footers, cookie banners or chat widgets. Use `scroll-padding-top` for sticky headers (2.4.11).
- [ ] Hidden things are really hidden: content hidden with `opacity: 0` or a transform must also have `visibility: hidden`, `display: none` or `hidden`, so it can't be focused while invisible (2.4.7, 2.4.3).
- [ ] When JavaScript moves the view, focus moves too. An in-page link that calls `preventDefault()` to smooth-scroll must move focus to the target, or the next Tab continues from the old position (2.4.3).
- [ ] Dialogs:
  - focus moves in when one opens and stays inside while it's modal
  - Esc closes it
  - focus returns to the trigger
  - prefer the native `<dialog>` with `showModal()` (2.1.2, 2.4.3)
- [ ] Nothing changes context just because something received focus or input (3.2.1, 3.2.2).
- [ ] Content that appears on hover or focus can be dismissed with Esc, can be hovered itself, and stays until dismissed (1.4.13).

## Images and graphics

- [ ] Informative images have `alt` that gives their meaning in context, not "image of". Decorative images have `alt=""`. Linked images describe the link destination (1.1.1).
- [ ] CSS `background-image` is used only for decoration. Meaningful images use `<img>` with `alt` (1.1.1).
- [ ] Inline SVG:
  - decorative: `aria-hidden="true" focusable="false"`
  - informative: `role="img"` plus `aria-label` or `<title>` (1.1.1)
  - icons use `currentColor` or theme variables so they follow the theme and forced colours
- [ ] Charts and complex images have a text alternative or a data table nearby (1.1.1).
- [ ] No text in images, except logos (1.4.5).
- [ ] Video/audio: captions, transcripts and audio description where needed. No autoplay with sound. Moving content longer than 5 seconds can be paused (1.2.x, 1.4.2, 2.2.2).

## Colour and contrast

- [ ] Run the contrast-check skill: 4.5:1 for text, 3:1 for large text and for UI parts and graphics, in **every** theme (1.4.3, 1.4.11).
- [ ] The project's colour rules are followed, such as only using theme variables or which colours may go together.
- [ ] Colour is never the only cue. Links inside text are underlined, or have 3:1 against the surrounding text plus a non-colour cue on hover and focus. States such as active, error, selected and required are shown by more than colour (1.4.1).
- [ ] Forced colours (Windows contrast themes): backgrounds and shadows disappear, so:
  - meaning carried by `background-color` or `box-shadow` (dots, bars, active markers, focus rings made with shadows) needs a border, an outline or `@media (forced-colors: active)` styles
  - SVG icons should use `currentColor`
  (1.4.11, best practice)
- [ ] `color-scheme` matches each theme, so form controls and scrollbars follow it.

## Text, zoom and layout

- [ ] Font sizes are in `rem`/`em`, never `px`. The viewport meta has no `maximum-scale` or `user-scalable=no` (1.4.4).
- [ ] Reflow at 320 CSS px wide with no horizontal scrolling:
  - no fixed `px` widths on content (use `max-width`)
  - no fixed heights on text boxes
  - long words and URLs wrap
  - data tables may scroll inside their own container
  (1.4.10)
- [ ] Text spacing can be increased (line height 1.5, paragraph spacing 2em, letter spacing 0.12em, word spacing 0.16em) without text being clipped. Avoid `overflow: hidden` and fixed heights on text, and `px` line heights (1.4.12).
- [ ] Orientation isn't locked (1.3.4).
- [ ] Uppercase comes from `text-transform`, not typed capitals, because some screen readers spell out capitalised words (best practice).

## Motion and animation

- [ ] Nothing flashes more than 3 times a second (2.3.1).
- [ ] Transitions, animations, parallax and smooth scrolling respect `prefers-reduced-motion`. JavaScript `scrollTo({ behavior: 'smooth' })` and JS animations don't follow CSS rules, so check `matchMedia('(prefers-reduced-motion: reduce)')` (2.3.3 is AAA, best practice here).
- [ ] Carousels, tickers and animation that start automatically and last more than 5 seconds can be paused (2.2.2).

## JavaScript

- [ ] The page works without JavaScript, or controls that need it stay `hidden` until it runs, so they never appear broken.
- [ ] Custom widgets follow the WAI-ARIA Authoring Practices pattern in full: roles, states and keyboard support. Use a native element when there is one (4.1.2).
- [ ] ARIA state is set from the actual state at load, and updated on every change (4.1.2).
- [ ] Status messages (such as "Copied", form results, loading or cart updates) use a live region (`role="status"` or `role="alert"`) and don't move focus (4.1.3).
- [ ] Time limits can be turned off, adjusted or extended (2.2.1).
- [ ] No single-key shortcuts unless they can be turned off or remapped (2.1.4).
- [ ] Dragging always has a single-pointer alternative (2.5.7). Gestures that use more than one finger or follow a path have a simple alternative (2.5.1).

## Forms

- [ ] Every field has a visible `<label>`. Groups use `<fieldset>`/`<legend>`. Instructions and the required format are in text (3.3.2, 1.3.1).
- [ ] `autocomplete` is set on personal data fields (1.3.5).
- [ ] Errors are described in text, linked to their field with `aria-describedby`, and explain how to fix them. On submit, focus moves to an error summary or the first invalid field (3.3.1, 3.3.3).
- [ ] Legal, financial or data-deleting submissions can be reviewed, corrected or reversed (3.3.4).
- [ ] People are never asked for the same information twice (3.3.7).
- [ ] Logging in doesn't depend on memory or puzzle tests: password managers and paste work, and there are no image CAPTCHAs without an alternative (3.3.8).

## Content (CMS pages, Markdown, HTML)

- [ ] Headings start one level below the page title the template prints, usually `<h2>`, and go down in order. Bold paragraphs are not used as headings.
- [ ] Link text, alt text and lists follow the rules above. No empty paragraphs used for spacing.
- [ ] Leftovers pasted from Word or Google Docs, such as `class="MsoNormal"`, `<o:p>` or `<span style>`, are removed.
- [ ] Instructions don't rely on shape, colour, size or position alone, for example "the red button on the right" (1.3.3).
- [ ] Abbreviations are written out the first time. Plain language and short sentences (best practice).
- [ ] Quotes use `<blockquote>`, and code uses `<code>`/`<pre>`.
- [ ] Linked documents (PDF, Word) are accessible themselves, or there's an accessible alternative.
