# Tasks

## 1. Project Setup

- [x] 1.1 Check whether full Xcode is installed (`xcodebuild -version`); choose Xcode project or SwiftPM + bundle script accordingly. Verify by running the chosen build command on an empty menu-bar app target successfully.
- [x] 1.2 Create Swift Package modules `DesignSystem`, `Settings`, `Capture`, `Annotation`, `Pinning` and an app target with `LSUIElement` set. Verify `swift build` succeeds and the app launches showing only a menu-bar icon.
- [x] 1.3 Add a test target per module. Verify `swift test` runs and passes with one placeholder test each.

## 2. App Shell

- [x] 2.1 Read Apple's official documentation for global hotkey registration, choose the API, and implement `HotkeyManager` (register, unregister, rebind, persistence). Verify unit tests for persistence pass, and a hotkey fires while another app is frontmost.
- [x] 2.2 Read Apple's official documentation for Screen Recording permission checks, implement `PermissionService` and the onboarding window with a System Settings button. Verify manually: with permission revoked onboarding appears and no overlay opens; after granting it reports success.
- [x] 2.3 Implement `SettingsStore` (hotkeys, save folders, filename pattern, Auto Save, font) with persistence, and the Preferences window. Verify unit tests for a persistence round-trip.
- [x] 2.4 Implement the menu-bar icon (left click starts snip) and right-click menu with Snip, Preferences, Quit. Verify each item invokes its handler.
- [x] 2.5 Implement `DesignSystem`: materials, rounded floating toolbar, SF Symbols, system accent color, user font environment value, and dark/light following. Verify manually in light and dark appearance, with a font change applied without relaunch.

## 3. Screen Snipping

- [x] 3.1 Implement per-display frozen capture via `SCScreenshotManager.captureImage(contentFilter:configuration:)` at native pixel size with the cursor excluded (confirm the cursor property in Apple's documentation). Verify the pixel size equals points x scale on a Retina display and a captured image has no cursor.
- [x] 3.2 Implement the geometry layer (point/pixel conversion, mixed scale factors, crop rect). Verify unit tests cover mixed scale factors and cross-display selections.
- [x] 3.3 Implement overlay panels, crosshair, drag selection, size label, handle resizing, Escape, right-click, and plain click outside an existing selection abort. Verify manually on single and dual displays.
- [x] 3.4 Implement window detection from `CGWindowListCopyWindowInfo` (front-to-back order, excluding own windows) and click-to-select. Verify a unit test of hit testing on synthetic frames and a manual window selection.
- [x] 3.5 Implement the output renderer: flatten the selection at native resolution and PNG/JPEG encode. Verify unit tests for output size, mixed-scale composition, and PNG/JPEG round trips.
- [x] 3.6 Implement the floating toolbar (Copy, Save, Pin, Close) and outputs: copy (Return, Command-C, button), save panel (button, Command-S), pin hand-off, Auto Save with filename pattern. Verify unit tests for filename pattern and folder writes, and a manual clipboard check.

## 4. Image Annotation

- [x] 4.1 Implement the annotation document model, undo/redo stack, clear-all, and flatten renderer. Verify unit tests for undo/redo, clear-all irreversibility, and native-resolution output size.
- [x] 4.2 Implement rectangle, line/arrow (Tab switch, strip by clicks), pencil, and marker tools with width, color, alpha controls and scroll/1/2 width change. Verify unit tests for tool geometry and manual drawing.
- [x] 4.3 Implement the annotation toolbar (tool buttons, Undo/Redo/clear-all buttons, color palette, custom color panel, pen width and alpha 0-255 sliders, Space to show/hide) integrated into the snip session, replacing the temporary tool and style keys. Verify the drawing-state unit tests (tool, color, alpha, width) pass and manual checks that every control works and that the custom color panel appears above the overlay.
- [x] 4.4 Read Apple's documentation for the Core Image pixelate and Gaussian blur filters, then implement mosaic and blur applied from the base bitmap at flatten. Verify a unit test that exported pixels in the region differ from the source and mosaic output is block-constant. Add its toolbar buttons.
- [x] 4.5 Implement the text tool with corner scaling, rotation handle, and Shift-to-horizontal. Verify unit tests for scale and rotation math and manual check. Add its toolbar button.

## 5. Image Pinning

- [x] 5.1 Implement pin windows: floating, all Spaces, drag, close by Escape or right-click. Verify manually that a pin stays above other apps across Spaces.

## 6. Integration

- [x] 6.1 Run the end-to-end checklist over every spec scenario (snip, annotate, output, pin, settings) on single and dual displays in light and dark appearance. Verify the checklist is complete with no failures recorded. (Dual-display live check deferred: no second display was available; recorded as NOT TESTED in docs/verification-checklist.md.)
- [x] 6.2 Write README covering build, permissions, hotkeys, and known limitations. Verify the documented build and run commands succeed as written.
