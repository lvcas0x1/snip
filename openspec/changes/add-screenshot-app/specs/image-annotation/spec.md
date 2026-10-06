# Spec Delta

## Purpose

Lets the user mark up and redact a snipped image with drawing, text, and obscuring tools before outputting it.

## ADDED Requirements

### Requirement: Annotation toolbar
The system SHALL show an annotation toolbar during a snip session with a button for each tool and for Undo, Redo, and clear all, and SHALL let the user show or hide it with Space.

#### Scenario: Choose a tool
- **WHEN** the user clicks a tool button
- **THEN** that tool becomes active, its button is highlighted, and style controls for color, width, and alpha are shown

#### Scenario: Leave a tool
- **WHEN** the user clicks the active tool's button again
- **THEN** no tool is active and drawing stops

#### Scenario: Toggle toolbar
- **WHEN** the user presses Space during a snip session
- **THEN** the annotation controls hide if visible, or show if hidden, and no tool stays active while hidden

### Requirement: Rectangle tool
The system SHALL provide a rectangle tool that draws a rectangle outline from a drag.

#### Scenario: Draw rectangle
- **WHEN** the rectangle tool is active and the user drags from A to B
- **THEN** a rectangle with corners A and B is added using the current color, alpha, and width

### Requirement: Line and arrow tools
The system SHALL provide a line tool and an arrow tool, switchable with Tab, supporting a single line by dragging and a line strip by successive clicks.

#### Scenario: Single arrow
- **WHEN** the arrow tool is active and the user drags from A to B
- **THEN** an arrow from A to B is added

#### Scenario: Switch with Tab
- **WHEN** the line tool is active and the user presses Tab
- **THEN** the arrow tool becomes active, and the reverse

#### Scenario: Line strip
- **WHEN** the user clicks at three points and right-clicks
- **THEN** a line strip through the three points is added and editing of that shape finishes

### Requirement: Pencil and marker tools
The system SHALL provide a freehand pencil and a semi-transparent marker with a wider stroke.

#### Scenario: Freehand stroke
- **WHEN** the pencil is active and the user drags along a path
- **THEN** a stroke following that path is added

#### Scenario: Marker translucency
- **WHEN** the marker draws over text
- **THEN** the underlying content remains visible through the stroke

### Requirement: Mosaic and Gaussian blur
The system SHALL provide mosaic and Gaussian blur tools that irreversibly obscure the covered area in output.

#### Scenario: Mosaic output
- **WHEN** the user covers a region with mosaic and outputs
- **THEN** pixels in that region are pixelated and the original content cannot be recovered from the output

#### Scenario: Blur output
- **WHEN** the user covers a region with Gaussian blur and outputs
- **THEN** pixels in that region are blurred and the original content cannot be recovered from the output

### Requirement: Text tool
The system SHALL provide a text tool whose text box can be scaled by dragging its corners and rotated by dragging a handle above it.

#### Scenario: Add text
- **WHEN** the text tool is active and the user clicks and types "Hello"
- **THEN** "Hello" appears at the click position in the current color

#### Scenario: Scale
- **WHEN** the user drags a text box corner outward
- **THEN** the text enlarges

#### Scenario: Rotate
- **WHEN** the user drags the rotation handle
- **THEN** the text rotates by the dragged angle

#### Scenario: Keep horizontal
- **WHEN** the user holds Shift before dragging a corner of rotated text
- **THEN** the text becomes horizontal

#### Scenario: Snap to right angles
- **WHEN** the user holds Shift while dragging the rotation handle and the angle is within 8 degrees of 0, 90, 180, or 270 degrees
- **THEN** the rotation snaps to that angle

#### Scenario: Free rotation
- **WHEN** the user drags the rotation handle without Shift, or Shift is held but the angle is more than 8 degrees from every right angle
- **THEN** the rotation follows the pointer exactly

### Requirement: Undo, redo, and clear all
The system SHALL support Undo (Command-Z) and Redo (Command-Y) of annotation operations, and clear all edits (Shift-Command-Z), which cannot be undone.

#### Scenario: Undo and redo
- **WHEN** the user adds a shape, presses Command-Z, then Command-Y
- **THEN** the shape is removed, then restored

#### Scenario: Clear all
- **WHEN** the user presses Shift-Command-Z after adding three shapes
- **THEN** all annotations are removed and Redo restores nothing

### Requirement: Pen width, color, and alpha
The system SHALL let the user change pen width with the mouse scroll or the 1 and 2 keys while editing, choose a color from a palette or a custom color, and set alpha from 0 to 255.

#### Scenario: Width by scroll
- **WHEN** the user scrolls up while a drawing tool is active
- **THEN** the pen width increases

#### Scenario: Palette color
- **WHEN** the user clicks a palette swatch
- **THEN** subsequent annotations use that color

#### Scenario: Custom color
- **WHEN** the user picks a custom color in the color dialog
- **THEN** subsequent annotations use that color

#### Scenario: Alpha
- **WHEN** the user sets alpha to 128
- **THEN** subsequent annotations are about half transparent

### Requirement: Annotations are flattened on output
The system SHALL include annotations in any copied, saved, auto-saved, or pinned output at native resolution.

#### Scenario: Copy annotated image
- **WHEN** the user copies a snip containing annotations
- **THEN** the clipboard image includes the annotations
