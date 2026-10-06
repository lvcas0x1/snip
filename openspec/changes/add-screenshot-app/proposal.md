# Proposal

## Why

macOS has no native screenshot tool that combines region snipping, pinning images as floating windows, and annotation in one lightweight app. Snipaste offers this workflow, but it is a cross-platform Qt application whose look does not follow macOS design conventions. A native Swift app can deliver the selected Snipaste core features while looking and behaving like a first-class macOS app.

## What Changes

- Add a new native macOS menu-bar app written in Swift (SwiftUI + AppKit), with no Dock icon by default.
- Add region snipping: hotkey or menu-bar click, frozen-screen overlay, window detection, cursor excluded from captures, copy / save / pin output through a floating toolbar, and auto save.
- Add pinning: show a snip as an always-on-top window that can be dragged and closed.
- Add annotation: rectangle, line, arrow, pencil, marker, mosaic, Gaussian blur, text, Undo/Redo, clear all, pen width, custom color and alpha.
- Add settings: configurable snip hotkey, interface font, and system theme following.
- Define a modern visual design: translucent materials, rounded floating toolbars, system accent color, SF Symbols.

Selected feature IDs (from the Snipaste feature list in the conversation): A1, A2, A7, A10 (auto save only), A11, C1-C6, C8, C9, E1, E2, E6.

## Capabilities

### New Capabilities
- `screen-snipping`: Region capture overlay with window detection, and output to clipboard, file, auto save, or pin.
- `image-pinning`: Floating always-on-top windows created from snips that can be dragged and closed.
- `image-annotation`: Shape, freehand, text, and redaction tools with style controls, Undo/Redo, and flattening on output.
- `app-shell`: Menu-bar presence, permission onboarding, configurable snip hotkey, interface font, and system theme following.

### Modified Capabilities

None. `openspec/specs/` is empty.

## Impact

- New Xcode/Swift Package project in this repository (currently empty apart from OpenSpec files).
- Target: macOS 14 or later (assumption; see design.md). `SCScreenshotManager` requires macOS 14.0 per Apple's documentation.
- System permission: Screen Recording.
- Dependencies: Apple frameworks only (ScreenCaptureKit, AppKit, SwiftUI, Core Graphics, Core Image). No third-party packages planned.
- Supersedes the earlier draft of this change that also covered color picking, capture history, OCR, and screen recording; those are not selected and are removed from scope.
- Out of scope: rounded-corner output (A14), Quick Save (part of A10), pin zoom/rotate/flip (B2, B3), eraser (C7), Shift-constrained shapes (C10), all dropped by the user; B1 (pin from clipboard) and B9 (hide/show all pins), both dropped by the user; A9 (custom-size capture and whiteboard mode; dropped by the user), keyboard-driven pixel control (WASD cursor, arrow-key move/enlarge/shrink; dropped by the user), Windows/Linux, OCR, QR decoding, history replay, color picker, recording, cloud sharing, UI element detection below window level, ellipse and shape rotation, App Store distribution.

## Assumptions

- A7 ("screenshot without mouse cursor") is read as: captures never include the mouse cursor. Snipaste's option shows/hides the cursor; this app omits the option.
