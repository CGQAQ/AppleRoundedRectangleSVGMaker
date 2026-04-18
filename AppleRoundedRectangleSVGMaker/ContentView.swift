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
        HStack(spacing: 4) {
            Text(label)
                .foregroundColor(.secondary)
                .font(.caption)
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

struct ContentView: View {
    @State private var cornerRadius: Double = 20
    @State private var viewBoxWidth: Double = 300
    @State private var viewBoxHeight: Double = 300
    @State private var fillAlpha: Double = 100
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
          <path d="\(svgPath)" fill="blue" fill-opacity="\(String(format: "%.2f", fillAlpha / 100))" />
        </svg>
        """
    }

    var body: some View {
        VStack {
            VStack {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.blue.opacity(fillAlpha / 100))
                    .frame(width: min(viewBoxWidth, 300), height: min(viewBoxHeight, 300))
            }
            .frame(maxWidth: .infinity)
            .background(Color.clear)
            .padding()

            VStack {
                HStack(spacing: 16) {
                    DraggableNumberField(label: "W", value: $viewBoxWidth)
                    DraggableNumberField(label: "H", value: $viewBoxHeight)
                    DraggableNumberField(label: "A", value: $fillAlpha, range: 0...100)
                }
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
            .padding()
            .background(.background)
        }
    }
}

#Preview {
    ContentView()
}
