# Design

## Context

The repository is empty apart from OpenSpec files. Toolchain observed locally: Swift 6.4, Command Line Tools at `/Library/Developer/CommandLineTools`, macOS 27.0.1; full Xcode was not found. See proposal.md for motivation and scope; specs under `specs/` define behavior.

API availability checked against Apple's documentation data (https://developer.apple.com/documentation/screencapturekit/scscreenshotmanager):
- `SCScreenshotManager`: macOS 14.0. `captureImage(contentFilter:configuration:)` is available there; `captureScreenshot(rect:configuration:)` requires macOS 26.0 and is not used.
- `SMAppService` (if launch-at-login is added later): macOS 13.0.

Not verified against official docs yet: the global-hotkey registration API, the Screen Recording permission preflight/request calls, Core Image filters for mosaic and blur, and . Tasks 2.1, 2.2, 4.3, and 5.1 resolve these before use.

## Goals / Non-Goals

**Goals:**
- One native app target with no third-party dependencies.
- Capture, overlay, and annotation rendering at native pixel resolution.
- One design system (materials, toolbar components, font and theme handling) shared by all windows.
- Core logic in modules testable with `swift test` without launching UI.

**Non-Goals:**
- Mac App Store distribution and sandboxing.
- macOS earlier than 14.
- UI element detection below window level (Snipaste's element detection needs Accessibility; not selected).

## Decisions

1. **Deployment target macOS 14.** `SCScreenshotManager.captureImage` is available from 14.0. No selected feature needs a later API. Alternative: macOS 15 or 26. Rejected; no benefit for the selected scope and it narrows users.

2. **Swift Package modules + thin app target.** Modules: `Capture`, `Annotation`, `Pinning`, `Settings`, `DesignSystem`; the app target wires them. Alternative: single target. Rejected because modules enforce boundaries and keep logic testable. Building a signed `.app` needs full Xcode; task 1.1 checks this first.

3. **Capture with ScreenCaptureKit.** The snip session captures one frozen image per display with `SCScreenshotManager.captureImage(contentFilter:configuration:)`, with `SCStreamConfiguration` set to native pixel size and `showsCursor = false` to satisfy the cursor-excluded requirement (property name to confirm in task 3.1). Selection crops the frozen image, so output equals what the user saw. Alternative: `CGWindowListCreateImage` (legacy). Rejected.

4. **Overlay as one borderless `NSPanel` per display** at a high window level, drawing the frozen image, dimming layer, selection, handles, size label, and annotations. SwiftUI hosts the toolbar and Preferences. Alternative: SwiftUI-only overlay. Rejected because per-pixel mouse tracking and Escape/Return key handling are more reliable in AppKit.

5. **Window detection from `CGWindowListCopyWindowInfo`** (on-screen windows, documented in `CGWindow.h` as ordered front to back), snapshotted when the session starts, excluding the app's own windows, transparent windows, desktop-level windows, and windows under 10x10 points; hit-tested at the cursor, first match wins. Window bounds are already in global top-left points. Alternative: `SCShareableContent.windows` (z-order is not documented). Rejected. Alternative: Accessibility-based element detection. Rejected as out of scope and as it adds a second permission.



8. **Annotation as a vector document model** with value-type shapes and an undo/redo stack; output flattens with Core Graphics at native resolution. Mosaic and blur read the base bitmap at flatten time, so the original pixels never persist in the output. Alternative: draw into a bitmap immediately. Rejected because it prevents per-shape Undo/Redo.

9. **Pins as borderless `NSWindow`s** at floating level, joining all Spaces via `collectionBehavior`. Pins are dragged by the window background and closed with Escape or a right-click. Alternative: single full-screen canvas. Rejected because dragging, focus, and Mission Control behavior come free with windows.


11. **Output destinations.** Copy via `NSPasteboard`; Save via `NSSavePanel`; Auto Save writes to the folder from Settings using a filename pattern. Sandbox is off, so folder access needs no security-scoped bookmarks.

12. **Hotkeys and permission.** Global hotkeys use a system-level registration that does not require Accessibility; the specific API is chosen in task 2.1 after reading official documentation. Permission state is checked before every capture (task 2.2).

13. **Design system and theming.** `DesignSystem` provides toolbar components on materials, SF Symbols, system accent color, and an environment value for the user-selected font. Light/dark follows `NSApp.effectiveAppearance`. Alternative: fixed custom palette. Rejected because the goal is a native look and E6 requires system theme following.

## Risks / Trade-offs

- [Full Xcode may be missing, blocking app-bundle build and signing] → Task 1.1 checks; fall back to a SwiftPM executable plus a script that assembles the `.app` bundle.
- [Screen Recording permission resets after OS updates or re-signing, producing wallpaper-only captures] → Check permission before each capture; use a stable signing identity.
- [Mixed scale factors cause off-by-one crops] → All geometry in each display's pixel space; unit tests with synthetic scale factors.
- [Frozen capture latency before the overlay appears] → Capture displays concurrently; measure against a 150 ms target.
- [The first ScreenCaptureKit call shows a system consent dialog (Allow / Open System Settings) and the capture waits until the user answers; observed on macOS 27 during task 3.1] → Treat the first capture as pending without a timeout error, and keep the onboarding text explaining that this dialog appears.

## Open Questions

- App name, bundle identifier, and icon (metadata only).
- Default hotkey set (any set meeting the app-shell requirement is acceptable).
- Default Auto Save folder (any user-visible folder under Pictures is acceptable).
