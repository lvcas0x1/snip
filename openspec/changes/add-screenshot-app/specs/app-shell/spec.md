# Spec Delta

## Purpose

Defines the app's menu-bar presence, permission onboarding, hotkeys, interface font, and theme behavior so all features feel like one native macOS app.

## ADDED Requirements

### Requirement: Menu-bar app
The system SHALL run as a menu-bar app with no Dock icon and provide a right-click menu with Snip, Preferences, and Quit.

#### Scenario: Launch
- **WHEN** the app launches
- **THEN** a menu-bar icon appears and no Dock icon is shown

#### Scenario: Menu
- **WHEN** the user right-clicks the menu-bar icon
- **THEN** the menu lists those actions with their hotkeys

### Requirement: Permission onboarding
The system SHALL show onboarding that explains why Screen Recording permission is needed, links to System Settings, and detects when it is granted.

#### Scenario: Grant detected
- **WHEN** the user grants permission while onboarding is shown
- **THEN** onboarding reports success and capture becomes available

### Requirement: Configurable hotkeys
The system SHALL let the user set a global hotkey for snip, working while any app is frontmost.

#### Scenario: Default
- **WHEN** the app is first launched
- **THEN** the snip action has a default hotkey

#### Scenario: Rebind
- **WHEN** the user records a new key combination for snip
- **THEN** the new combination starts a snip and the old one does not

#### Scenario: Persistence
- **WHEN** the user relaunches the app
- **THEN** the configured hotkeys are still active

### Requirement: Interface font
The system SHALL let the user choose the font used for interface text, and SHALL apply it to the toolbar, panels, and Preferences.

#### Scenario: Change font
- **WHEN** the user selects a font in Preferences
- **THEN** interface text uses that font without relaunch

#### Scenario: Default font
- **WHEN** no font is chosen
- **THEN** the system font is used

### Requirement: Follow system theme
The system SHALL follow the system light/dark appearance and accent color.

#### Scenario: Dark appearance
- **WHEN** the system appearance switches to dark
- **THEN** toolbars, panels, and Preferences switch to dark styling without relaunch

#### Scenario: Accent color
- **WHEN** the user changes the system accent color
- **THEN** selection outlines and active tool highlights use the new color

### Requirement: Preferences persistence
The system SHALL persist all user settings across launches.

#### Scenario: Persist
- **WHEN** the user changes the auto save folder, filename pattern, or font and relaunches
- **THEN** the changed values are retained

### Requirement: Native visual design
The system SHALL draw toolbars and panels with native macOS materials, SF Symbols, and rounded corners.

#### Scenario: Toolbar appearance
- **WHEN** a toolbar is shown
- **THEN** it is drawn on a system material with rounded corners and SF Symbols icons
