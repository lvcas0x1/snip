# Spec Delta

## Purpose

Lets the user keep a snipped image visible as a floating window above all other windows for reference while working.

## ADDED Requirements

### Requirement: Floating window behavior
The system SHALL show each pin, created from a snip, in a borderless window that stays above regular windows on every Space, can be dragged to move, and closes with Escape or a right-click.

#### Scenario: Always on top
- **WHEN** the user activates another app
- **THEN** the pin remains visible above that app's windows

#### Scenario: Drag
- **WHEN** the user drags a pin
- **THEN** the pin follows the cursor

#### Scenario: Close
- **WHEN** a pin is focused and the user presses Escape
- **THEN** that pin closes
