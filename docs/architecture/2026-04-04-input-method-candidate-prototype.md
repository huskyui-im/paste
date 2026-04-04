# Input Method Candidate Prototype

## Goal

Start a new architecture path for Quick Paste that does **not** depend on deep Accessibility traversal to follow the caret in every app.

The long-term target is an input-method style candidate experience:

- candidate UI positioned by the text input system
- less dependence on browser / WebView AX trees
- no recursive AX graph walking in the critical path

## Why a New Branch

The previous Quick Paste implementation mixed together:

- popup presentation
- clipboard selection
- cross-app caret lookup
- AX fallback heuristics

That made experimentation risky and hard to reason about.

This branch introduces an explicit seam:

- `QuickPasteWindow` handles window presentation only
- `QuickPasteAnchorProviding` decides where the popup should appear
- future input-method work can replace the provider instead of rewriting the window again

## What Is Implemented In This Branch

### 1. Anchor provider abstraction

Added:

- `Paste/QuickPasteAnchoring.swift`

This defines:

- `QuickPasteAnchor`
- `QuickPasteAnchorProviding`
- `QuickPasteArchitectureMode`

### 2. Accessibility provider extracted

Added:

- `Paste/AccessibilityQuickPasteAnchorProvider.swift`

This keeps the current AX-based anchor lookup isolated from the window code.

### 3. Input-method prototype scaffold

Added:

- `Paste/InputMethodQuickPastePrototype.swift`
- `Paste/InputMethodQuickPasteCandidateController.swift`
- `Paste/PasteInputMethodController.swift`

This now includes a first InputMethodKit-side skeleton:

- `InputMethodQuickPasteCandidateController` wraps `IMKCandidates`
- `PasteInputMethodController` subclasses `IMKInputController`
- candidate items are sourced from clipboard history

It still does **not** provide system-wide caret tracking yet because the app does not have a dedicated input-method target or bundle wiring.

### 4. Window presentation decoupled

Updated:

- `Paste/QuickPasteWindow.swift`
- `Paste/AppDelegate.swift`

The window now consumes an anchor provider instead of owning AX logic directly.

## Next Milestones

- Create a dedicated InputMethodKit target
- Add the input method bundle `Info.plist` / connection name wiring
- Move candidate selection flow into the input method lifecycle
- Reuse the existing clipboard list UI as the candidate content source
- Define how Quick Paste is invoked when the input method is active

## Current Limitation

The app still defaults to:

- `QuickPasteArchitectureMode.accessibilityWindow`

That keeps current behavior working while we build the new architecture in parallel.
