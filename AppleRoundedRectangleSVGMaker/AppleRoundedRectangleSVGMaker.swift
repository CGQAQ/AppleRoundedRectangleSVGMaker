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

class TransparentNSView: NSView {
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard let window = window else { return }
        window.isOpaque = false
        window.backgroundColor = .clear
    }
}

struct WindowAccessor: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        TransparentNSView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if let window = nsView.window {
            window.isOpaque = false
            window.backgroundColor = .clear
        }
    }
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
