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
    @State private var isEditing = false
    @State private var textValue = ""

    var body: some View {
        HStack(spacing: 6) {
            Text(label)
                .foregroundColor(.primary)
                .font(.system(.body, design: .monospaced).bold())
                .fixedSize()
            if isEditing {
                TextField("", text: $textValue)
                    .font(.system(.body, design: .monospaced))
                    .frame(width: 50)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        if let num = Double(textValue) {
                            value = min(max(num, range.lowerBound), range.upperBound)
                        }
                        isEditing = false
                    }
            } else {
                Text("\(Int(value))")
                    .font(.system(.body, design: .monospaced))
                    .frame(width: 50)
                    .padding(.vertical, 4)
                    .padding(.horizontal, 6)
                    .background(RoundedRectangle(cornerRadius: 6).fill(.quaternary))
                    .contentShape(Rectangle())
                    .cursor(.resizeUpDown)
                    .gesture(
                        DragGesture(coordinateSpace: .local)
                            .onChanged { gesture in
                                if dragStartValue == nil {
                                    dragStartValue = value
                                }
                                let delta = -gesture.translation.height
                                value = min(max((dragStartValue ?? value) + delta, range.lowerBound), range.upperBound)
                            }
                            .onEnded { _ in
                                dragStartValue = nil
                            }
                    )
                    .onTapGesture(count: 2) {
                        textValue = "\(Int(value))"
                        isEditing = true
                    }
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
    let combScale: Double = 3000
    let combPadding: Double = 150

    var body: some View {
        Canvas { context, size in
            let offsetRect = CGRect(x: combPadding, y: combPadding, width: rect.width, height: rect.height)
            let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            let path = shape.path(in: offsetRect)

            var segments: [(start: CGPoint, end: CGPoint, cp1: CGPoint, cp2: CGPoint)] = []
            var currentPoint = CGPoint.zero
            var firstPoint = CGPoint.zero

            path.forEach { element in
                switch element {
                case .move(to: let p):
                    currentPoint = p
                    firstPoint = p
                case .line(to: let p):
                    currentPoint = p
                case .curve(to: let p, control1: let cp1, control2: let cp2):
                    segments.append((start: currentPoint, end: p, cp1: cp1, cp2: cp2))
                    currentPoint = p
                case .quadCurve(to: let p, control: _):
                    currentPoint = p
                case .closeSubpath:
                    currentPoint = firstPoint
                }
            }

            let samplesPerSegment = 25

            for segment in segments {
                let p0 = segment.start
                let p1 = segment.cp1
                let p2 = segment.cp2
                let p3 = segment.end

                var combPath = Path()
                var started = false

                for i in 0...samplesPerSegment {
                    let t = Double(i) / Double(samplesPerSegment)
                    let mt = 1.0 - t

                    // B(t)
                    let x = mt*mt*mt*p0.x + 3*mt*mt*t*p1.x + 3*mt*t*t*p2.x + t*t*t*p3.x
                    let y = mt*mt*mt*p0.y + 3*mt*mt*t*p1.y + 3*mt*t*t*p2.y + t*t*t*p3.y

                    // B'(t)
                    let dx = 3*mt*mt*(p1.x-p0.x) + 6*mt*t*(p2.x-p1.x) + 3*t*t*(p3.x-p2.x)
                    let dy = 3*mt*mt*(p1.y-p0.y) + 6*mt*t*(p2.y-p1.y) + 3*t*t*(p3.y-p2.y)

                    // B''(t)
                    let ddx = 6*mt*(p2.x - 2*p1.x + p0.x) + 6*t*(p3.x - 2*p2.x + p1.x)
                    let ddy = 6*mt*(p2.y - 2*p1.y + p0.y) + 6*t*(p3.y - 2*p2.y + p1.y)

                    // Curvature
                    let cross = dx * ddy - dy * ddx
                    let denom = pow(dx*dx + dy*dy, 1.5)
                    let curvature = denom > 0.0001 ? abs(cross) / denom : 0

                    // Normal (pointing inward)
                    let len = sqrt(dx*dx + dy*dy)
                    guard len > 0.0001 else { continue }
                    let nx = dy / len
                    let ny = -dx / len

                    let combLen = curvature * combScale
                    let tipX = x + nx * combLen
                    let tipY = y + ny * combLen

                    // Draw hair
                    var hair = Path()
                    hair.move(to: CGPoint(x: x, y: y))
                    hair.addLine(to: CGPoint(x: tipX, y: tipY))
                    context.stroke(hair, with: .color(.orange.opacity(0.6)), lineWidth: 0.5)

                    // Build envelope
                    if !started {
                        combPath.move(to: CGPoint(x: tipX, y: tipY))
                        started = true
                    } else {
                        combPath.addLine(to: CGPoint(x: tipX, y: tipY))
                    }
                }

                // Close envelope back along the curve
                for i in stride(from: samplesPerSegment, through: 0, by: -1) {
                    let t = Double(i) / Double(samplesPerSegment)
                    let mt = 1.0 - t
                    let x = mt*mt*mt*p0.x + 3*mt*mt*t*p1.x + 3*mt*t*t*p2.x + t*t*t*p3.x
                    let y = mt*mt*mt*p0.y + 3*mt*mt*t*p1.y + 3*mt*t*t*p2.y + t*t*t*p3.y
                    combPath.addLine(to: CGPoint(x: x, y: y))
                }
                combPath.closeSubpath()

                // Fill with gradient
                context.fill(combPath, with: .linearGradient(
                    Gradient(colors: [.yellow, .orange, .pink]),
                    startPoint: CGPoint(x: offsetRect.midX, y: offsetRect.midY),
                    endPoint: CGPoint(x: offsetRect.maxX, y: offsetRect.minY)
                ))
            }

            // Draw the path outline
            context.stroke(path, with: .color(.gray), lineWidth: 1)
        }
        .frame(width: rect.width + combPadding * 2, height: rect.height + combPadding * 2)
        .allowsHitTesting(false)
    }
}

struct ContentView: View {
    @State private var cornerRadius: Double = 20
    @State private var viewBoxWidth: Double = 300
    @State private var viewBoxHeight: Double = 300
    @State private var fillAlpha: Double = 100
    @State private var useFill = true
    @State private var transparentBackground = false
    @State private var showCurvatureComb = false
    @State private var showCopiedToast = false

    var svgPath: String {
        let rect = CGRect(x: 0, y: 0, width: viewBoxWidth, height: viewBoxHeight)
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
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
        <svg xmlns="http://www.w3.org/2000/svg" width="\(Int(viewBoxWidth))" height="\(Int(viewBoxHeight))" viewBox="0 0 \(Int(viewBoxWidth)) \(Int(viewBoxHeight))">
          <path d="\(svgPath)" \(useFill ? "fill=\"blue\" fill-opacity=\"\(String(format: "%.2f", fillAlpha / 100))\"" : "fill=\"none\" stroke=\"blue\" stroke-opacity=\"\(String(format: "%.2f", fillAlpha / 100))\" stroke-width=\"2\"")" />
        </svg>
        """
    }

    var body: some View {
        HStack(spacing: 0) {
            VStack {
                ZStack {
                    if useFill {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(.blue.opacity(fillAlpha / 100))
                            .frame(width: viewBoxWidth, height: viewBoxHeight)
                    } else {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(.blue.opacity(fillAlpha / 100), lineWidth: 2)
                            .frame(width: viewBoxWidth, height: viewBoxHeight)
                    }
                    if showCurvatureComb {
                        CurvatureCombView(
                            cornerRadius: cornerRadius,
                            rect: CGRect(x: 0, y: 0, width: viewBoxWidth, height: viewBoxHeight)
                        )
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(transparentBackground ? Color.clear : Color(.windowBackgroundColor))

            VStack {
                HStack(spacing: 16) {
                    DraggableNumberField(label: "W", value: $viewBoxWidth)
                    DraggableNumberField(label: "H", value: $viewBoxHeight)
                    DraggableNumberField(label: "A", value: $fillAlpha, range: 0...100)
                }
                .padding(.horizontal)

                Toggle("Curvature Comb", isOn: $showCurvatureComb)
                    .padding(.horizontal)

                Toggle("Fill", isOn: $useFill)
                    .padding(.horizontal)

                Toggle("Transparent Background", isOn: $transparentBackground)
                    .padding(.horizontal)

                Slider(value: $cornerRadius, in: 0...min(viewBoxWidth, viewBoxHeight) / 2)
                    .padding(.horizontal)

                Text("Corner Radius: \(Int(cornerRadius))")
                    .foregroundColor(.secondary)

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
