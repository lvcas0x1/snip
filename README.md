# Snip

A native macOS menu-bar app (Swift, AppKit + SwiftUI) for snipping the screen, annotating the snip, and pinning it on screen.
The planning artifacts are in `openspec/changes/add-screenshot-app/` (proposal, specs, design, tasks).

## Requirements

- macOS 14 or later.
- Xcode (built and tested with Xcode 27.0). The active developer directory may be the Command Line Tools; the scripts below set `DEVELOPER_DIR` to `/Applications/Xcode.app/Contents/Developer` unless you override it.
- No third-party packages.

## Build and run

```bash
Scripts/build-app.sh          # release build -> build/Snip.app
Scripts/build-app.sh debug    # debug build
open build/Snip.app
```

The app has no Dock icon; look for the camera icon in the menu bar.

### Signing and the Screen Recording permission

macOS ties the Screen Recording permission to the app's code signature. With ad-hoc signing (`codesign --sign -`) the signature changes on every build, so the permission is lost after each rebuild.
`Scripts/build-app.sh` therefore signs with a local code-signing identity named `Screenshot Dev` when one exists in your keychain, and falls back to ad-hoc signing with a warning otherwise. Use another identity with `SIGN_IDENTITY="My Identity" Scripts/build-app.sh`.

There is no notarization and no App Store packaging.

## Tests

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
```

Per-scenario verification status for every spec scenario: [`docs/verification-checklist.md`](docs/verification-checklist.md).

## Permissions

- **Screen Recording** is required to snip. Without it, a snip does not start and an onboarding window explains what to enable in System Settings > Privacy & Security > Screen Recording.
- On the first capture macOS may show a one-time dialog (Allow / Open System Settings); the capture waits until it is answered.
- No Accessibility permission is needed.

## Using it

Start a snip with the hotkey (default **⌥/** (Option+/), configurable in Preferences) or a left click on the menu-bar icon. A right click on the icon opens the menu (Snip, Preferences, Quit).

### Snipping

| Action | How |
|---|---|
| Select a window | Move over it and click |
| Select an area | Drag; resize with the handles, move by dragging inside |
| Abort | Esc, right-click (when no tool is active), the Close button, or a click outside the selection |
| Copy | Return, ⌘C, or the Copy button |
| Save | ⌘S or the Save button (PNG or JPEG, set in Preferences) |
| Pin | The Pin button |

The selection size is shown in pixels. Output is at the display's native pixel resolution. The mouse cursor is never captured. Optional **Auto Save** (Preferences) also writes every copied, saved, or pinned snip to a folder (default `~/Pictures/Snip/Auto`); the filename pattern uses `{...}` groups in `DateFormatter` syntax, e.g. `Snip {yyyy-MM-dd HH.mm.ss}`, and existing files are never overwritten.

### Annotating

After selecting an area, pick a tool in the toolbar:

- Rectangle, line, arrow, pencil, marker, text, mosaic, blur.
- Line: click points and right-click to finish a polyline, or drag for a single line. **Tab** switches between line and arrow.
- Text: click to place, type (Japanese input works), **Esc** to finish. Drag a corner to scale, drag the top handle to rotate; hold **Shift** while rotating to snap to 0/90/180/270 degrees, hold **Shift** when grabbing a corner to level rotated text.
- Mosaic and blur replace the pixels underneath, so the original content cannot be recovered from the saved image.
- Color palette, custom color, alpha (0-255), and pen width (1-24 pt; scroll or the **1** / **2** keys).
- **⌘Z** undo, **⌘Y** redo, **⇧⌘Z** clear all. **Space** hides or shows the annotation controls.

### Pins

A pinned snip stays above other windows on every Space (including full-screen apps). Drag it to move it; **Esc** (after clicking it) or a right-click closes it.

### Preferences

Snip hotkey, image format, Auto Save, filename pattern, and interface font. Appearance follows the system light/dark setting and accent color.

## Project layout

```
Sources/
  Capture/       screen capture, geometry, window detection, selection logic, rendering, file output
  Annotation/    annotation model, drawing tools, redaction (Core Image), text, undo/redo
  Pinning/       pin windows
  Settings/      settings store, hotkey registration (Carbon)
  DesignSystem/  toolbar components, interface font
  Snip/          app, overlay, toolbar, Preferences
Scripts/         build-app.sh, Info.plist
docs/            verification checklist
```

## Known limitations

- Dual-display behavior is covered by unit tests only; it has not been checked on two physical displays.
- Text can be scaled and rotated only while it is being edited; once finished it cannot be re-edited. Clicking inside the box being edited starts a new text instead of moving the caret.
- A mosaic or blur placed over earlier annotations hides the part of those annotations inside its area (it is built from the original screen pixels).
- Pins cannot be scaled, rotated, or flipped, are not restored after the app quits, and there is no way to create a pin from the clipboard.
- Window detection selects whole windows only (no UI elements inside a window).
- The default hotkey (Option+/) is an Option-only combination, which macOS 15.0 and 15.1 refuse to register (macOS 14 and 15.2 or later accept it); on those versions pick another combination in Preferences. It may also conflict with another app's shortcut. If a new combination cannot be registered, Preferences shows an error; a failure at launch is only written to the log (subsystem `dev.lvcas0x1.snip`).
- Not implemented (dropped from the scope): custom-size capture, whiteboard mode, Quick Save, rounded-corner output, eraser, Shift-constrained shapes, keyboard pixel control, clipboard pinning, show/hide all pins, color picker, history, OCR, recording.
