//
//  ContentView.swift
//  RoundedRectangle
//
//  Created by Jason Leo on 2026/4/18.
//

import SwiftUI
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

struct DraggableNumberField: View {
    let label: String
    @Binding var value: Double
    var range: ClosedRange<Double> = 1...1000

    @State private var dragStartValue: Double?

    var body: some View {
        HStack(spacing: 6) {
            Text(label)
                .foregroundColor(.primary)
                .font(.system(.body, design: .monospaced).bold())
                .fixedSize()
                .contentShape(Rectangle())
                .cursor(.resizeUpDown)
                .gesture(
                    DragGesture(coordinateSpace: .local)
                        .onChanged { gesture in
                            if dragStartValue == nil {
                                dragStartValue = value
                            }
                            let delta = -gesture.translation.height
                            value = (min(max((dragStartValue ?? value) + delta, range.lowerBound), range.upperBound)).rounded()
                        }
                        .onEnded { _ in
                            dragStartValue = nil
                        }
                )
            TextField("", value: $value, format: .number)
                .font(.system(.body, design: .monospaced))
                .frame(width: 60)
                .textFieldStyle(.roundedBorder)
                .onSubmit {
                    value = min(max(value, range.lowerBound), range.upperBound)
                }
        }
    }
}

extension View {
    func cursor(_ cursor: NSCursor) -> some View {
        onHover { inside in
            if inside {
                cursor.push()
            } else {
                NSCursor.pop()
            }
        }
    }
}

struct CurvatureCombView: View {
    let cornerRadius: Double
    let rect: CGRect
    var combScale: Double
    var combPadding: Double
    let samplesPerCurve: Int = 40
    let samplesPerLine: Int = 4

    struct CombSample {
        let point: CGPoint
        let tip: CGPoint
        let curvature: Double
    }

    var body: some View {
        Canvas { context, size in
            let offsetRect = CGRect(x: combPadding, y: combPadding, width: rect.width, height: rect.height)
            let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            let path = shape.path(in: offsetRect)

            // Collect all path elements
            enum PathElement {
                case move(CGPoint)
                case line(CGPoint)
                case curve(CGPoint, CGPoint, CGPoint) // end, cp1, cp2
                case close
            }

            var elements: [PathElement] = []
            path.forEach { element in
                switch element {
                case .move(to: let p):
                    elements.append(.move(p))
                case .line(to: let p):
                    elements.append(.line(p))
                case .curve(to: let p, control1: let cp1, control2: let cp2):
                    elements.append(.curve(p, cp1, cp2))
                case .quadCurve(to: let p, control: _):
                    elements.append(.line(p))
                case .closeSubpath:
                    elements.append(.close)
                }
            }

            // Sample the entire path continuously
            var allSamples: [CombSample] = []
            var currentPoint = CGPoint.zero
            var firstPoint = CGPoint.zero

            for element in elements {
                switch element {
                case .move(let p):
                    currentPoint = p
                    firstPoint = p

                case .line(let p):
                    // Sample line segments with zero curvature
                    let dx = p.x - currentPoint.x
                    let dy = p.y - currentPoint.y
                    let lineLen = sqrt(dx * dx + dy * dy)
                    guard lineLen > 0.1 else {
                        currentPoint = p
                        continue
                    }
                    let nx = dy / lineLen  // outward normal
                    let ny = -dx / lineLen
                    for i in 0...samplesPerLine {
                        let t = Double(i) / Double(samplesPerLine)
                        let x = currentPoint.x + dx * t
                        let y = currentPoint.y + dy * t
                        let pt = CGPoint(x: x, y: y)
                        allSamples.append(CombSample(point: pt, tip: pt, curvature: 0))
                        _ = (nx, ny) // suppress warning
                    }
                    currentPoint = p

                case .curve(let end, let cp1, let cp2):
                    let p0 = currentPoint
                    let p1 = cp1
                    let p2 = cp2
                    let p3 = end

                    for i in 0...samplesPerCurve {
                        let t = Double(i) / Double(samplesPerCurve)
                        let mt = 1.0 - t

                        // B(t)
                        let x = mt*mt*mt*p0.x + 3*mt*mt*t*p1.x + 3*mt*t*t*p2.x + t*t*t*p3.x
                        let y = mt*mt*mt*p0.y + 3*mt*mt*t*p1.y + 3*mt*t*t*p2.y + t*t*t*p3.y

                        // B'(t)
                        let bx = 3*mt*mt*(p1.x-p0.x) + 6*mt*t*(p2.x-p1.x) + 3*t*t*(p3.x-p2.x)
                        let by = 3*mt*mt*(p1.y-p0.y) + 6*mt*t*(p2.y-p1.y) + 3*t*t*(p3.y-p2.y)

                        // B''(t)
                        let ddx = 6*mt*(p2.x - 2*p1.x + p0.x) + 6*t*(p3.x - 2*p2.x + p1.x)
                        let ddy = 6*mt*(p2.y - 2*p1.y + p0.y) + 6*t*(p3.y - 2*p2.y + p1.y)

                        let cross = bx * ddy - by * ddx
                        let denom = pow(bx*bx + by*by, 1.5)
                        let curvature = denom > 0.0001 ? abs(cross) / denom : 0

                        let len = sqrt(bx*bx + by*by)
                        guard len > 0.0001 else { continue }
                        // Outward normal
                        let nx = by / len
                        let ny = -bx / len

                        let combLen = curvature * combScale
                        let pt = CGPoint(x: x, y: y)
                        let tip = CGPoint(x: x + nx * combLen, y: y + ny * combLen)
                        allSamples.append(CombSample(point: pt, tip: tip, curvature: curvature))
                    }
                    currentPoint = end

                case .close:
                    // Add closing line if needed
                    let dx = firstPoint.x - currentPoint.x
                    let dy = firstPoint.y - currentPoint.y
                    let lineLen = sqrt(dx * dx + dy * dy)
                    if lineLen > 0.1 {
                        for i in 0...samplesPerLine {
                            let t = Double(i) / Double(samplesPerLine)
                            let x = currentPoint.x + dx * t
                            let y = currentPoint.y + dy * t
                            let pt = CGPoint(x: x, y: y)
                            allSamples.append(CombSample(point: pt, tip: pt, curvature: 0))
                        }
                    }
                    currentPoint = firstPoint
                }
            }

            guard allSamples.count > 2 else { return }

            // Find max curvature for normalization
            let maxCurvature = allSamples.map(\.curvature).max() ?? 1.0
            guard maxCurvature > 0.0001 else { return }

            // Color function: maps normalized curvature (0...1) to yellow → orange → pink
            func combColor(for normalizedK: Double) -> Color {
                let t = min(max(normalizedK, 0), 1)
                // Yellow (1.0, 0.85, 0.2) → Orange (1.0, 0.5, 0.2) → Pink (0.95, 0.25, 0.45)
                let r: Double
                let g: Double
                let b: Double
                if t < 0.5 {
                    let u = t / 0.5
                    r = 1.0
                    g = 0.85 - 0.35 * u  // 0.85 → 0.5
                    b = 0.2
                } else {
                    let u = (t - 0.5) / 0.5
                    r = 1.0 - 0.05 * u   // 1.0 → 0.95
                    g = 0.5 - 0.25 * u    // 0.5 → 0.25
                    b = 0.2 + 0.25 * u    // 0.2 → 0.45
                }
                return Color(red: r, green: g, blue: b)
            }

            // Draw filled strips between adjacent samples, colored by curvature
            for i in 0..<(allSamples.count - 1) {
                let s0 = allSamples[i]
                let s1 = allSamples[i + 1]

                // Skip if both have negligible curvature
                let avgK = (s0.curvature + s1.curvature) / 2
                guard avgK > 0.0001 else { continue }

                var strip = Path()
                strip.move(to: s0.point)
                strip.addLine(to: s0.tip)
                strip.addLine(to: s1.tip)
                strip.addLine(to: s1.point)
                strip.closeSubpath()

                let normalizedK = avgK / maxCurvature
                let color = combColor(for: normalizedK).opacity(0.6)
                context.fill(strip, with: .color(color))
            }

            // Draw hair lines colored by curvature
            for sample in allSamples where sample.curvature > 0.001 {
                var hair = Path()
                hair.move(to: sample.point)
                hair.addLine(to: sample.tip)
                let normalizedK = sample.curvature / maxCurvature
                let color = combColor(for: normalizedK).opacity(0.5)
                context.stroke(hair, with: .color(color), lineWidth: 0.5)
            }

            // Draw the shape outline
            context.stroke(path, with: .color(.gray.opacity(0.6)), lineWidth: 1)
        }
        .frame(width: rect.width + combPadding * 2, height: rect.height + combPadding * 2)
        .allowsHitTesting(false)
    }
}

struct ReferenceLinesView: View {
    let cornerRadius: Double
    let width: Double
    let height: Double
    let padding: Double = 80

    var body: some View {
        Canvas { context, size in
            let rect = CGRect(x: padding, y: padding, width: width, height: height)
            let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            let path = shape.path(in: rect)

            // Collect curve start/end points and their tangent directions
            var currentPoint = CGPoint.zero
            var firstPoint = CGPoint.zero

            path.forEach { element in
                switch element {
                case .move(to: let p):
                    currentPoint = p
                    firstPoint = p
                case .line(to: let p):
                    currentPoint = p
                case .curve(to: let end, control1: let cp1, control2: let cp2):
                    // Tangent at curve start: direction from start toward cp1
                    let startTanX = cp1.x - currentPoint.x
                    let startTanY = cp1.y - currentPoint.y
                    let startLen = sqrt(startTanX * startTanX + startTanY * startTanY)

                    // Tangent at curve end: direction from cp2 toward end
                    let endTanX = end.x - cp2.x
                    let endTanY = end.y - cp2.y
                    let endLen = sqrt(endTanX * endTanX + endTanY * endTanY)

                    let lineExtension = max(width, height) * 0.3

                    if startLen > 0.01 {
                        let dx = startTanX / startLen
                        let dy = startTanY / startLen
                        var line = Path()
                        line.move(to: CGPoint(
                            x: currentPoint.x - dx * lineExtension,
                            y: currentPoint.y - dy * lineExtension
                        ))
                        line.addLine(to: CGPoint(
                            x: currentPoint.x + dx * lineExtension,
                            y: currentPoint.y + dy * lineExtension
                        ))
                        context.stroke(line, with: .color(.red.opacity(0.8)), lineWidth: 2)
                    }

                    if endLen > 0.01 {
                        let dx = endTanX / endLen
                        let dy = endTanY / endLen
                        var line = Path()
                        line.move(to: CGPoint(
                            x: end.x - dx * lineExtension,
                            y: end.y - dy * lineExtension
                        ))
                        line.addLine(to: CGPoint(
                            x: end.x + dx * lineExtension,
                            y: end.y + dy * lineExtension
                        ))
                        context.stroke(line, with: .color(.red.opacity(0.8)), lineWidth: 2)
                    }

                    currentPoint = end
                case .quadCurve(to: let p, control: _):
                    currentPoint = p
                case .closeSubpath:
                    currentPoint = firstPoint
                }
            }
        }
        .frame(width: width + padding * 2, height: height + padding * 2)
        .allowsHitTesting(false)
    }
}

struct ContentView: View {
    @State private var cornerRadius: Double = 20
    @State private var viewBoxWidth: Double = 300
    @State private var viewBoxHeight: Double = 300
    @State private var fillAlpha: Double = 100
    @State private var useFill = true
    @State private var iconMode = false
    @State private var transparentBackground = false
    @State private var showCurvatureComb = false
    @State private var showReferenceLines = false
    @State private var combScale: Double = 300
    @State private var combPadding: Double = 80

    @State private var showCopiedToast = false

    var effectiveCornerRadius: Double {
        if iconMode {
            return viewBoxWidth * 0.2237
        }
        return cornerRadius
    }

    var effectiveHeight: Double {
        iconMode ? viewBoxWidth : viewBoxHeight
    }

    var svgPath: String {
        let rect = CGRect(x: 0, y: 0, width: viewBoxWidth, height: effectiveHeight)
        let shape = RoundedRectangle(cornerRadius: effectiveCornerRadius, style: .continuous)
        let path = shape.path(in: rect)

        var svg = ""
        path.forEach { element in
            switch element {
            case .move(to: let p):
                svg += "M \(String(format: "%.2f", p.x)) \(String(format: "%.2f", p.y)) "
            case .line(to: let p):
                svg += "L \(String(format: "%.2f", p.x)) \(String(format: "%.2f", p.y)) "
            case .quadCurve(to: let p, control: let cp):
                svg += "Q \(String(format: "%.2f", cp.x)) \(String(format: "%.2f", cp.y)) \(String(format: "%.2f", p.x)) \(String(format: "%.2f", p.y)) "
            case .curve(to: let p, control1: let cp1, control2: let cp2):
                svg += "C \(String(format: "%.2f", cp1.x)) \(String(format: "%.2f", cp1.y)) \(String(format: "%.2f", cp2.x)) \(String(format: "%.2f", cp2.y)) \(String(format: "%.2f", p.x)) \(String(format: "%.2f", p.y)) "
            case .closeSubpath:
                svg += "Z"
            }
        }
        return svg
    }

    var fullSVG: String {
        """
        <svg xmlns="http://www.w3.org/2000/svg" width="\(Int(viewBoxWidth))" height="\(Int(effectiveHeight))" viewBox="0 0 \(Int(viewBoxWidth)) \(Int(effectiveHeight))">
          <path d="\(svgPath)" \(useFill ? "fill=\"blue\" fill-opacity=\"\(String(format: "%.2f", fillAlpha / 100))\"" : "fill=\"none\" stroke=\"blue\" stroke-opacity=\"\(String(format: "%.2f", fillAlpha / 100))\" stroke-width=\"2\"")" />
        </svg>
        """
    }

    var body: some View {
        HStack(spacing: 0) {
            VStack {
                ZStack {
                    if useFill {
                        RoundedRectangle(cornerRadius: effectiveCornerRadius, style: .continuous)
                            .fill(.blue.opacity(fillAlpha / 100))
                            .frame(width: viewBoxWidth, height: effectiveHeight)
                    } else {
                        RoundedRectangle(cornerRadius: effectiveCornerRadius, style: .continuous)
                            .stroke(.blue.opacity(fillAlpha / 100), lineWidth: 2)
                            .frame(width: viewBoxWidth, height: effectiveHeight)
                    }
                    if showReferenceLines {
                        ReferenceLinesView(
                            cornerRadius: effectiveCornerRadius,
                            width: viewBoxWidth,
                            height: effectiveHeight
                        )
                    }
                    if showCurvatureComb {
                        CurvatureCombView(
                            cornerRadius: effectiveCornerRadius,
                            rect: CGRect(x: 0, y: 0, width: viewBoxWidth, height: effectiveHeight),
                            combScale: combScale,
                            combPadding: combPadding
                        )
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(transparentBackground ? Color.clear : Color(.windowBackgroundColor))

            VStack {
                HStack(spacing: 16) {
                    DraggableNumberField(label: "W", value: $viewBoxWidth, range: 10...1000)
                    if !iconMode {
                        DraggableNumberField(label: "H", value: $viewBoxHeight, range: 10...1000)
                    }
                    DraggableNumberField(label: "A", value: $fillAlpha, range: 0...100)
                }
                .padding(.horizontal)

                Toggle("Icon Mode", isOn: $iconMode)
                    .padding(.horizontal)

                Toggle("Reference Lines", isOn: $showReferenceLines)
                    .padding(.horizontal)

                Toggle("Curvature Comb", isOn: $showCurvatureComb)
                    .padding(.horizontal)

                if showCurvatureComb {
                    HStack {
                        Text("Scale")
                            .foregroundColor(.secondary)
                        Slider(value: $combScale, in: 100...5000)
                        Text("\(Int(combScale))")
                            .foregroundColor(.secondary)
                            .frame(width: 50)
                    }
                    .padding(.horizontal)

                    HStack {
                        Text("Padding")
                            .foregroundColor(.secondary)
                        Slider(value: $combPadding, in: 20...200)
                        Text("\(Int(combPadding))")
                            .foregroundColor(.secondary)
                            .frame(width: 50)
                    }
                    .padding(.horizontal)
                }

                Toggle("Fill", isOn: $useFill)
                    .padding(.horizontal)

                Toggle("Transparent Background", isOn: $transparentBackground)
                    .padding(.horizontal)

                if !iconMode {
                    Slider(value: $cornerRadius, in: 0...min(viewBoxWidth, viewBoxHeight) / 2)
                        .padding(.horizontal)

                    Text("Corner Radius: \(Int(cornerRadius))")
                        .foregroundColor(.secondary)
                }

                TextEditor(text: .constant(fullSVG))
                    .font(.system(.caption, design: .monospaced))
                    .frame(height: 120)
                    .padding(4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(.secondary.opacity(0.3))
                    )
                    .padding(.horizontal)

                Button("Copy SVG Path") {
                    #if canImport(AppKit)
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(fullSVG, forType: .string)
                    #elseif canImport(UIKit)
                    UIPasteboard.general.string = fullSVG
                    #endif
                    showCopiedToast = true
                }
                .padding(.top, 8)
            }
            .overlay(alignment: .bottom) {
                if showCopiedToast {
                    Text("Copied!")
                        .font(.callout.weight(.medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(.black.opacity(0.75)))
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .padding(.bottom, 16)
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                withAnimation {
                                    showCopiedToast = false
                                }
                            }
                        }
                }
            }
            .animation(.easeInOut, value: showCopiedToast)
            .frame(maxHeight: .infinity)
            .background(.background)
        }
    }
}

#Preview {
    ContentView()
}
