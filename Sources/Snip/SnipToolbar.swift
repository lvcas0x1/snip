import Annotation
import DesignSystem
import SwiftUI

/// Everything the toolbar shows or does. The snip session keeps it in sync with the drawing state.
final class SnipToolbarModel: ObservableObject {
    @Published var tool: DrawingTool?
    @Published var baseColor = AnnotationColor.palette[0]
    @Published var alpha: CGFloat = 1
    @Published var width: CGFloat = 3
    @Published var canUndo = false
    @Published var canRedo = false
    /// Whether the annotation controls (tools and style row) are shown; toggled with Space.
    @Published var annotationBarVisible = true

    var selectTool: (DrawingTool) -> Void = { _ in }
    var undo: () -> Void = {}
    var redo: () -> Void = {}
    var clearAll: () -> Void = {}
    var setColor: (AnnotationColor) -> Void = { _ in }
    var setAlpha: (CGFloat) -> Void = { _ in }
    var setWidth: (CGFloat) -> Void = { _ in }
    var openColorPanel: () -> Void = {}
    var copy: () -> Void = {}
    var save: () -> Void = {}
    var pin: () -> Void = {}
    var close: () -> Void = {}
}

/// Floating toolbar shown next to the selection.
/// Row 1: annotation tools, history, then output actions. Row 2 (while a tool is active): color, width, alpha.
struct SnipToolbarView: View {
    /// Space reserved around the bar so its shadow is not clipped by the hosting view.
    static let outerPadding: CGFloat = 14

    @ObservedObject var model: SnipToolbarModel

    private static let tools: [(tool: DrawingTool, symbol: String, label: String)] = [
        (.rectangle, "rectangle", "Rectangle"),
        (.line, "line.diagonal", "Line (Tab: arrow)"),
        (.arrow, "arrow.up.right", "Arrow (Tab: line)"),
        (.pencil, "pencil.tip", "Pencil"),
        (.marker, "highlighter", "Marker"),
        (.text, "textformat", "Text"),
        (.mosaic, "square.grid.3x3.fill", "Mosaic"),
        (.blur, "drop", "Blur"),
    ]

    var body: some View {
        // Rows are right-aligned so the output buttons stay put when the wider style row appears.
        VStack(alignment: .trailing, spacing: 6) {
            FloatingToolbar {
                if model.annotationBarVisible {
                    ForEach(Self.tools, id: \.tool) { entry in
                        ToolbarButton(symbol: entry.symbol, label: entry.label, isActive: model.tool == entry.tool) {
                            model.selectTool(entry.tool)
                        }
                    }
                    Divider().frame(height: 18)
                    ToolbarButton(symbol: "arrow.uturn.backward", label: "Undo (\u{2318}Z)", isEnabled: model.canUndo, action: model.undo)
                    ToolbarButton(symbol: "arrow.uturn.forward", label: "Redo (\u{2318}Y)", isEnabled: model.canRedo, action: model.redo)
                    ToolbarButton(symbol: "trash", label: "Clear All (\u{21E7}\u{2318}Z)", isEnabled: model.canUndo, action: model.clearAll)
                    Divider().frame(height: 18)
                }
                ToolbarButton(symbol: "doc.on.doc", label: "Copy (\u{2318}C)", action: model.copy)
                ToolbarButton(symbol: "square.and.arrow.down", label: "Save\u{2026}", action: model.save)
                ToolbarButton(symbol: "pin", label: "Pin to Screen", action: model.pin)
                Divider().frame(height: 18)
                ToolbarButton(symbol: "xmark", label: "Close", action: model.close)
            }
            if model.annotationBarVisible, model.tool?.usesStrokeStyle == true {
                StyleRow(model: model)
            }
        }
        .padding(Self.outerPadding)
    }
}

private struct StyleRow: View {
    @ObservedObject var model: SnipToolbarModel

    var body: some View {
        FloatingToolbar {
            ForEach(Array(AnnotationColor.palette.enumerated()), id: \.offset) { _, color in
                Swatch(color: color, isSelected: color.sameHue(as: model.baseColor)) {
                    model.setColor(color.withAlpha(model.alpha))
                }
            }
            ToolbarButton(symbol: "paintpalette", label: "Custom Color\u{2026}", action: model.openColorPanel)
            Divider().frame(height: 18)
            if model.tool?.usesStrokeWidth == true {
                Image(systemName: "lineweight").foregroundStyle(.secondary).accessibilityHidden(true)
                // No `step`: a stepped Slider draws one tick per step, which turns the 0-255 alpha track into a dark band.
                Slider(
                    value: Binding(get: { Double(model.width) }, set: { model.setWidth(CGFloat($0.rounded())) }),
                    in: Double(DrawingController.widthRange.lowerBound)...Double(DrawingController.widthRange.upperBound)
                )
                .frame(width: 90)
                Text("\(Int(model.width))pt").monospacedDigit().font(.system(size: 11)).frame(width: 34, alignment: .leading)
            }
            Image(systemName: "circle.lefthalf.filled").foregroundStyle(.secondary).accessibilityHidden(true)
            Slider(
                value: Binding(get: { Double(model.alpha * 255) }, set: { model.setAlpha(CGFloat($0.rounded()) / 255) }),
                in: 0...255
            )
            .frame(width: 90)
            Text("\(Int((model.alpha * 255).rounded()))").monospacedDigit().font(.system(size: 11)).frame(width: 26, alignment: .leading)
        }
    }
}

private struct Swatch: View {
    let color: AnnotationColor
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(Color(.sRGB, red: color.red, green: color.green, blue: color.blue))
                .frame(width: 18, height: 18)
                .overlay(Circle().strokeBorder(Color.primary.opacity(0.25), lineWidth: 0.5))
                .padding(3)
                .overlay(Circle().strokeBorder(Color.accentColor, lineWidth: isSelected ? 2 : 0))
        }
        .buttonStyle(.plain)
    }
}

extension AnnotationColor {
    /// Same red, green, and blue; alpha is ignored.
    func sameHue(as other: AnnotationColor) -> Bool {
        red == other.red && green == other.green && blue == other.blue
    }
}
