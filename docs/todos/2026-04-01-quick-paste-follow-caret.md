# Quick Paste Follow Caret TODO

## Current Status

The issue is **not fixed yet**.

Observed behavior:
- In browser inputs and Codex chat inputs, the Quick Paste popup still does not reliably follow the real text caret.
- In some cases, the popup appears near the top area of the window instead of near the insertion point.
- The current Accessibility-based fallback is still too coarse for WebView/browser-style editors.

## Repro Cases

- Chrome address bar: move the caret to different positions, trigger `Cmd+Shift+V`, and verify whether the popup follows the caret.
- Codex chat input: click near the left, middle, and right side of the input, trigger `Cmd+Shift+V`, and verify whether the popup follows the caret.
- Web page textareas / rich text editors: test whether the popup follows the visible insertion point instead of the container.

## TODO

- [ ] Add structured debug logging for Accessibility lookup:
  - Focused element role / subrole
  - Editable state
  - Selected text range availability
  - Bounds-for-range result
  - Parent chain roles

- [ ] Verify whether the focused element in Chrome/Codex is the true editable node or only a `WebArea` / container.

- [ ] Inspect the parent and child Accessibility chain around the focused element to find the node that exposes real caret bounds.

- [ ] Try reading additional AX attributes that may help on WebView-based inputs:
  - `AXSelectedTextRange`
  - `AXVisibleCharacterRange`
  - `AXInsertionPointLineNumber`
  - any child editable text element exposed by the focused node

- [ ] If caret bounds are unavailable, improve fallback behavior:
  - Prefer the actual input box rect
  - Avoid anchoring to the whole window top area
  - For chat-style apps, anchor near the bottom composer region

- [ ] Add a temporary debug mode that prints the chosen anchor source:
  - `caret`
  - `input-frame`
  - `window-composer-fallback`
  - `screen-center`

- [ ] Validate multi-app behavior after each change:
  - Chrome address bar
  - Codex input box
  - standard native macOS text fields

- [ ] Decide whether WebView/browser apps need app-specific heuristics when Accessibility cannot provide a real caret rect.

## Non-Blocking Related Work

- [ ] Clean up the existing `#Preview` build issue in `/Users/huskyui/github-repo/paste/Paste/ContentView.swift`.
- [ ] Consider moving persisted clipboard history out of `UserDefaults` if image history needs to survive app restarts.
