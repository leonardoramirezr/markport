# Markport

Native macOS app for exporting Markdown to PDF with custom CSS + HTML styles.
No external dependencies: system AppKit, SwiftUI, and WebKit. The binary weighs ~1 MB.

## Build

```bash
make          # builds build/Markport.app
make run      # builds and opens the app
make install  # copies the app to /Applications
```

`build.sh` compiles all `src/**/*.swift` with `swiftc -O -wmo`, assembles the bundle,
generates the icon if missing (`tools/make-icon.sh`), and signs it with an ad-hoc signature.

## How it works

The first time you open it, it asks you to define a style. After that the main
screen appears: a style bar on the left (each one with a real thumbnail of the
document at page size) and the Markdown area on the right, with the
**Export PDF** button (⌘E).

### A style

A style is a folder at `~/Library/Application Support/Markport/Styles/<id>/`:

```
style.css        stylesheet (defines @page, typography, margins…)
template.html    template with {{ title }} and {{ content }}
meta.json        name and date
fonts/           optional assets referenced by the CSS via relative path
```

The document is composed inside that folder, so the CSS's relative paths
(`url("fonts/sans-400.woff2")`) resolve just like on disk, and bundled fonts
get embedded in the PDF.

If the template has no `{{ content }}` marker, the content is injected into the
`<body>`; if it links no stylesheet, `<link rel="stylesheet" href="style.css">` is added.

### Typography

- **System font…** lists only installed families and pastes the `font-family`
  declaration at the CSS editor's cursor.
- **Add font…** copies `.woff2/.woff/.otf/.ttf` files into `fonts/` and generates
  the corresponding `@font-face` rules.
- The editor warns if the CSS references a family that's neither installed nor bundled.

### Page size

The CSS's `@page` rules: `size` (A3/A4/A5/Letter/Legal/Tabloid/Executive, explicit
measurements, `landscape`) and `margin` (mm, cm, in, pt, px) are translated into
`NSPrintInfo`, so the PDF comes out with the paper size and margins the stylesheet declares.

## Structure

```
src/App/     lifecycle, state, and draft persistence
src/Core/    Markdown -> HTML, @page -> NSPrintInfo, rendering, thumbnails, fonts
src/UI/      onboarding, main screen, style editor, font picker
tools/       icon generator
```

## Technical notes

- **Custom Markdown** (`src/Core/Markdown.swift`): headings, paragraphs, nested
  lists, blockquotes, rules, code blocks, GFM tables, emphasis, links, images,
  and embedded HTML. Avoids pulling in an external package and keeps startup
  instant.
- **Pagination**: the PDF is generated with `NSPrintOperation.runModal(for:…)` on
  an offscreen `WKWebView`. `run()` doesn't work: it blocks the run loop, WebKit
  never reports the page count, and the operation paginates endlessly.
- **Startup**: the renderer's auxiliary `NSWindow` is created lazily; instantiating
  it during startup prevents SwiftUI from mounting its scene.
- **Editor**: `NSTextView` with a debounced notification (0.28s) instead of
  `TextEditor`, so typing doesn't redraw SwiftUI on every keystroke.
- **Thumbnails**: generated one at a time offscreen and saved to `Cache/`, with
  the CSS+HTML fingerprint in the filename to invalidate them on edit.
