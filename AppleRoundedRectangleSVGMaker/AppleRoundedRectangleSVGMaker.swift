//
//  AppleRoundedRectangleSVGMaker.swift
//  RoundedRectangle
//
//  Created by Jason Leo on 2026/4/18.
//

import SwiftUI

struct TransparentWindowModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(WindowAccessor())
    }
}

struct WindowAccessor: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                window.isOpaque = false
                window.backgroundColor = .clear
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

@main
struct RoundedRectangleApp: App {
    var body: some Scene {
        WindowGroup("RoundedRectangleSVGMaker") {
            ContentView()
                .modifier(TransparentWindowModifier())
        }
    }
}
