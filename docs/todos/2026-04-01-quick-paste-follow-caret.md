# Quick Paste Follow Caret TODO

## Current Status

Core fixes applied on **2026-04-02**. Needs multi-app validation.

Observed behavior:
- In browser inputs and Codex chat inputs, the Quick Paste popup still does not reliably follow the real text caret.
- In some cases, the popup appears near the top area of the window instead of near the insertion point.
- The current Accessibility-based fallback is still too coarse for WebView/browser-style editors.

## Repro Cases

- Chrome address bar: move the caret to different positions, trigger `Cmd+Shift+V`, and verify whether the popup follows the caret.
- Codex chat input: click near the left, middle, and right side of the input, trigger `Cmd+Shift+V`, and verify whether the popup follows the caret.
- Web page textareas / rich text editors: test whether the popup follows the visible insertion point instead of the container.

## TODO

- [x] Add structured debug logging for Accessibility lookup:
  - Focused element role / subrole
  - Editable state
  - Selected text range availability
  - Bounds-for-range result
  - Parent chain roles
  - **Done (2026-04-02):** Added `debugAnchorLogging` flag, `debugLog()`, `dumpElementInfo()` in `QuickPasteWindow.swift`.

- [x] Verify whether the focused element in Chrome/Codex is the true editable node or only a `WebArea` / container.
  - **Done (2026-04-02):** Added `findEditableInChildren()` which searches children of the focused element (up to depth 5) to find the actual editable node in WebView contexts.

- [x] Inspect the parent and child Accessibility chain around the focused element to find the node that exposes real caret bounds.
  - **Done (2026-04-02):** `getAnchorRect()` now tries: 1) direct focused element, 2) child search (new), 3) parent walk (existing), 4) input frame fallback, 5) window composer fallback.

- [x] Try reading additional AX attributes that may help on WebView-based inputs:
  - `AXSelectedTextRange`
  - `AXVisibleCharacterRange`
  - `AXInsertionPointLineNumber`
  - any child editable text element exposed by the focused node
  - **Done (2026-04-02):** Child search checks `AXEditable`, role/subrole, and `AXSelectedTextRange` availability to identify the correct editable node.

- [x] If caret bounds are unavailable, improve fallback behavior:
  - Prefer the actual input box rect
  - Avoid anchoring to the whole window top area
  - For chat-style apps, anchor near the bottom composer region
  - **Done (2026-04-02):** `focusedWindowComposerAnchor` now anchors 80px from the window bottom (was 140px from top). Input frame fallback uses `frame(of:)` with size validation.

- [x] Add a temporary debug mode that prints the chosen anchor source:
  - `caret`
  - `caretViaChild`
  - `caretViaParent`
  - `inputFrame`
  - `windowComposerFallback`
  - `screenCenter`
  - **Done (2026-04-02):** `AnchorSource` enum + `debugAnchorLogging` flag. Set `QuickPasteWindow.debugAnchorLogging = true` to enable.

- [ ] Validate multi-app behavior after each change:
  - Chrome address bar
  - Codex input box
  - standard native macOS text fields

- [ ] Decide whether WebView/browser apps need app-specific heuristics when Accessibility cannot provide a real caret rect.

## Non-Blocking Related Work

- [ ] Clean up the existing `#Preview` build issue in `/Users/huskyui/github-repo/paste/Paste/ContentView.swift`.
- [ ] Consider moving persisted clipboard history out of `UserDefaults` if image history needs to survive app restarts.
AP_AC3MP8YUKQF