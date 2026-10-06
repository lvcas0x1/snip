# Verification checklist

Every scenario of the change `add-screenshot-app` (the app is named Snip), with how it was verified. Generated from the spec files; edit the evidence column when a pending item is checked.

- Scenarios: 59
- Verified: 59
- Pending: 0

## Environment checks not yet covered

- **Dual displays (NOT TESTED)**: no second display was available. Geometry and rendering for mixed scale factors and selections spanning displays are unit-tested (`GeometryTests`, `SnipRendererTests.testMixedScaleSelectionComposesBothDisplays`), but no live run on two displays has been done. Retest when a second display is available.
- **Overlay and toolbar in dark appearance**: checked by the user on the running app, in addition to rendered images.

## Scenarios

| Capability | Requirement | Scenario | Status | Evidence |
|---|---|---|---|---|
| app-shell | Menu-bar app | Launch | Manual | Task 1.2: activation type UIElement, no Dock icon; menu-bar icon shown (user-confirmed). |
| app-shell | Menu-bar app | Menu | Manual | Task 2.4 and later trims: right-click menu lists Snip, Preferences, Quit; every item invoked (log-verified, user-confirmed). |
| app-shell | Permission onboarding | Grant detected | Automated | PermissionServiceTests.testMonitorReportsGrantOnce. The live label change to 'Permission granted' was never observed on screen. |
| app-shell | Configurable hotkeys | Default | Automated + manual | HotkeyStoreTests.testEveryActionHasADefault; the default hotkey fired from another app (log-verified). |
| app-shell | Configurable hotkeys | Rebind | Automated + manual | HotkeyStoreTests.testRebindPersistsAcrossInstances; rebinding in Preferences and starting a snip with the new combination (user-confirmed). |
| app-shell | Configurable hotkeys | Persistence | Automated | HotkeyStoreTests.testRebindPersistsAcrossInstances. |
| app-shell | Interface font | Change font | Manual | Task 2.5: font change applied without relaunch (user-confirmed). |
| app-shell | Interface font | Default font | Automated | InterfaceFontTests (nil, empty, unknown family fall back to the system font). |
| app-shell | Follow system theme | Dark appearance | Manual | Task 2.5: Preferences switched to dark; the overlay toolbar was checked in dark appearance (both user-confirmed). |
| app-shell | Follow system theme | Accent color | Manual | Task 2.5: accent color followed the system setting (user-confirmed). |
| app-shell | Preferences persistence | Persist | Automated | SettingsStoreTests.testPersistenceRoundTrip. |
| app-shell | Native visual design | Toolbar appearance | Manual | Rendered previews (light and dark) and live use: system material, rounded corners, SF Symbols (user-confirmed). |
| image-annotation | Annotation toolbar | Choose a tool | Manual | Task 4.3 (user-confirmed). |
| image-annotation | Annotation toolbar | Leave a tool | Manual | Task 4.3 (user-confirmed). |
| image-annotation | Annotation toolbar | Toggle toolbar | Manual | Task 4.3: Space shows/hides the annotation controls (user-confirmed). |
| image-annotation | Rectangle tool | Draw rectangle | Automated + manual | DrawingControllerTests.testRectangleDragAddsNormalizedRectangleWithCurrentStyle, ShapeRenderingTests.testRectangleDrawsOutlineOnly; task 4.2 (user-confirmed). |
| image-annotation | Line and arrow tools | Single arrow | Automated + manual | DrawingControllerTests.testArrowDragAddsArrowAndClickDoesNothing; task 4.2 (user-confirmed). |
| image-annotation | Line and arrow tools | Switch with Tab | Automated + manual | DrawingControllerTests.testTabSwitchesBetweenLineAndArrowOnly; task 4.2 (user-confirmed). |
| image-annotation | Line and arrow tools | Line strip | Automated + manual | DrawingControllerTests.testLineStripBuiltByClicksAndFinishedByRightClick; user-confirmed after the on-screen hint was added. |
| image-annotation | Pencil and marker tools | Freehand stroke | Automated + manual | DrawingControllerTests.testPencilCollectsThePointerPath; task 4.2 (user-confirmed). |
| image-annotation | Pencil and marker tools | Marker translucency | Automated + manual | ShapeRenderingTests.testMarkerStrokeLetsTheBaseShowThrough; task 4.2 (user-confirmed). |
| image-annotation | Mosaic and Gaussian blur | Mosaic output | Automated + manual | RedactionTests (block-constant, outside untouched); task 4.4 (user-confirmed). |
| image-annotation | Mosaic and Gaussian blur | Blur output | Automated + manual | RedactionTests.testBlurSoftensASharpEdgeInsideTheRegionOnly; task 4.4 (user-confirmed). |
| image-annotation | Text tool | Add text | Automated + manual | DrawingControllerTests text tests, TextAnnotationTests (upright, Japanese); task 4.5 (user-confirmed, including Japanese input). |
| image-annotation | Text tool | Scale | Automated + manual | DrawingControllerTests.testDraggingACornerOutwardEnlargesTheTextProportionally; task 4.5 (user-confirmed). |
| image-annotation | Text tool | Rotate | Automated + manual | DrawingControllerTests.testDraggingTheTopHandleToTheRightRotatesAQuarterTurn; task 4.5 (user-confirmed). |
| image-annotation | Text tool | Keep horizontal | Automated | DrawingControllerTests.testShiftOnACornerLevelsRotatedText. The user found this gesture hard to use and asked for the snap instead; not confirmed manually. |
| image-annotation | Text tool | Snap to right angles | Automated + manual | TextAnnotationTests snap tests, DrawingControllerTests.testShiftSnapsRotationNearARightAngle; user-confirmed. |
| image-annotation | Text tool | Free rotation | Automated + manual | DrawingControllerTests.testWithoutShiftRotationIsFree; used during task 4.5 checks. |
| image-annotation | Undo, redo, and clear all | Undo and redo | Automated + manual | AnnotationDocumentTests.testUndoRemovesLastAndRedoRestoresIt; task 4.3 (user-confirmed). |
| image-annotation | Undo, redo, and clear all | Clear all | Automated + manual | AnnotationDocumentTests.testClearAllCannotBeUndoneOrRedone; task 4.3 (user-confirmed). |
| image-annotation | Pen width, color, and alpha | Width by scroll | Automated + manual | DrawingControllerTests.testWidthIsClampedAndAdjustable; task 4.2 (user-confirmed). |
| image-annotation | Pen width, color, and alpha | Palette color | Manual | Task 4.3 (user-confirmed). |
| image-annotation | Pen width, color, and alpha | Custom color | Manual | Task 4.3: the color panel appears above the overlay (user-confirmed). |
| image-annotation | Pen width, color, and alpha | Alpha | Automated + manual | DrawingControllerTests.testCustomColorWithAlphaIsSplitIntoBaseAndAlpha; task 4.3 (user-confirmed). |
| image-annotation | Annotations are flattened on output | Copy annotated image | Automated + manual | AnnotationDocumentTests flatten tests; task 4.3 step 8 (user-confirmed). |
| image-pinning | Floating window behavior | Always on top | Automated + manual | PinWindowTests.testPinStaysAboveRegularWindowsOnEverySpace; task 5.1: other Spaces, other apps, full-screen apps (user-confirmed). |
| image-pinning | Floating window behavior | Drag | Manual | Task 5.1 (user-confirmed). |
| image-pinning | Floating window behavior | Close | Automated + manual | PinWindowTests.testEscapeClosesThePin, testRightClickClosesThePin; task 5.1 (user-confirmed). |
| screen-snipping | Start snipping | Start with hotkey | Manual | Tasks 2.1 and 3.3; the cursor fix was user-confirmed. |
| screen-snipping | Start snipping | Start from menu-bar icon | Manual | Task 2.4: left click logged command: snip and opened the overlay. |
| screen-snipping | Start snipping | Abort | Manual | Task 3.3: Escape and right-click close the overlay (user-confirmed). |
| screen-snipping | Start snipping | Abort by clicking outside the selection | Automated + manual | SelectionModelTests outside-click tests; user-confirmed. |
| screen-snipping | Start snipping | Drag outside the selection | Automated + manual | SelectionModelTests.testDragOutsideSelectionStartsNewSelectionInsteadOfCancelling; user-confirmed. |
| screen-snipping | Window detection | Select window | Automated + manual | WindowDetectorTests; task 3.4 (user-confirmed). |
| screen-snipping | Window detection | Drag overrides detection | Manual | Task 3.4 (user-confirmed). |
| screen-snipping | Selection size display | Show size | Manual | Task 3.3 (user-confirmed). |
| screen-snipping | Selection size display | Retina size | Automated + manual | GeometryTests.testRetinaCropIsPointsTimesScale; task 3.3: size shown in pixels (user-confirmed). |
| screen-snipping | Cursor excluded | Cursor over selection | Manual | Task 3.1: the captured image contained no cursor (checked on the saved capture). |
| screen-snipping | Output actions | Copy by key | Manual | Task 3.6: Return and Command-C (user-confirmed). |
| screen-snipping | Output actions | Copy by button | Manual | Task 3.6 (user-confirmed). |
| screen-snipping | Output actions | Save by key | Manual | Command-S opens the same save panel as the Save button (user-confirmed). |
| screen-snipping | Output actions | Save | Manual | Task 3.6 (user-confirmed). |
| screen-snipping | Output actions | Close button | Manual | Task 3.6 (user-confirmed). |
| screen-snipping | Output actions | Pin | Manual | Task 5.1: pin appears at the selection's position (user-confirmed). |
| screen-snipping | Auto save | Auto save on | Automated + manual | OutputFilesTests (writer, no overwrite); task 3.6 (user-confirmed). |
| screen-snipping | Auto save | Auto save off | Manual | Task 3.6 (user-confirmed). |
| screen-snipping | Native resolution output | Retina output | Automated + manual | SnipRendererTests.testOutputIsAtNativePixelResolution; pasted image checked in task 3.6. |
| screen-snipping | Permission handling | Permission missing | Manual | Task 2.2: with permission missing, no overlay and the onboarding window appeared (log-verified). |
