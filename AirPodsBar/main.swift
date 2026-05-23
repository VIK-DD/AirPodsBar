// main.swift — explicit entry point for swiftc
// Don't use @main when compiling with swiftc directly (without xcodebuild)
import AppKit

let delegate = AppDelegate()
let app = NSApplication.shared
app.delegate = delegate
app.run()
