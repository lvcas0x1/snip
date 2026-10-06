# Spec Delta

## Purpose

Lets the user capture any region of the screen through a fast, precise overlay and send the result to the clipboard, a file, or a floating pin window.

## ADDED Requirements

### Requirement: Start snipping
The system SHALL start a snip session from a global hotkey or a left click on the menu-bar icon, showing a frozen image of every connected display with a selection overlay.

#### Scenario: Start with hotkey
- **WHEN** the user presses the snip hotkey while Screen Recording permission is granted
- **THEN** every display is covered by a frozen overlay and the cursor is a crosshair

#### Scenario: Start from menu-bar icon
- **WHEN** the user left-clicks the menu-bar icon
- **THEN** a snip session starts

#### Scenario: Abort
- **WHEN** the user presses Escape, or right-clicks while not editing
- **THEN** the overlay closes and no capture is produced

#### Scenario: Abort by clicking outside the selection
- **WHEN** a selection exists, no annotation tool is active, and the user clicks, without dragging, outside it
- **THEN** the overlay closes and no capture is produced

#### Scenario: Drag outside the selection
- **WHEN** a selection exists and the user drags outside it
- **THEN** a new selection replaces the old one and the overlay stays open

### Requirement: Window detection
The system SHALL highlight the window under the cursor and select its bounds on click.

#### Scenario: Select window
- **WHEN** the user clicks without dragging while a window is highlighted
- **THEN** the selection equals that window's bounds

#### Scenario: Drag overrides detection
- **WHEN** the user drags instead of clicking
- **THEN** the selection is the dragged rectangle

### Requirement: Selection size display
The system SHALL display the selection's width and height in pixels while a selection or highlighted window exists.

#### Scenario: Show size
- **WHEN** a selection exists
- **THEN** its width and height in pixels are displayed

#### Scenario: Retina size
- **WHEN** the user selects a 200x100 point region on a 2x display
- **THEN** the displayed size is 400 x 200

### Requirement: Cursor excluded
The system SHALL NOT include the mouse cursor in any captured image.

#### Scenario: Cursor over selection
- **WHEN** the mouse cursor is inside the selected region at capture time
- **THEN** the output image does not contain the cursor

### Requirement: Output actions
The system SHALL show a floating toolbar near the selection with Copy, Save, Pin, and Close buttons, SHALL copy the selection with Return or Command-C, and SHALL open the save panel with Command-S.

#### Scenario: Copy by key
- **WHEN** the user presses Return or Command-C while a selection exists
- **THEN** the clipboard holds the image and the session ends

#### Scenario: Copy by button
- **WHEN** the user clicks the Copy button
- **THEN** the clipboard holds the image and the session ends

#### Scenario: Save by key
- **WHEN** the user presses Command-S while a selection exists
- **THEN** the same save panel as the Save button opens

#### Scenario: Save
- **WHEN** the user clicks the Save button
- **THEN** a save panel opens and the image is written in the chosen format (PNG or JPEG)

#### Scenario: Close button
- **WHEN** the user clicks the Close button
- **THEN** the overlay closes and no capture is produced

#### Scenario: Pin
- **WHEN** the user clicks the Pin button
- **THEN** a pin window with the image appears at the selection's on-screen position and the session ends

### Requirement: Auto save
The system SHALL support Auto Save, which writes every successful snip to the configured Auto Save folder when enabled.

#### Scenario: Auto save on
- **WHEN** Auto Save is enabled and the user copies a snip
- **THEN** the image is also written to the Auto Save folder

#### Scenario: Auto save off
- **WHEN** Auto Save is disabled and the user copies a snip
- **THEN** no file is written

### Requirement: Native resolution output
The system SHALL output images at the display's native pixel resolution on any display, including displays with different scale factors.

#### Scenario: Retina output
- **WHEN** the user snips a 200x100 point region on a 2x display
- **THEN** the output is 400x200 pixels

### Requirement: Permission handling
The system SHALL NOT start a capture without Screen Recording permission and SHALL guide the user to grant it.

#### Scenario: Permission missing
- **WHEN** the user presses the snip hotkey without permission
- **THEN** no overlay appears and an onboarding prompt with a button to open System Settings is shown
