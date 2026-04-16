// main.swift — entry point explicit pentru swiftc
// Nu folosi @main când compilezi cu swiftc direct (fără xcodebuild)
import AppKit

let delegate = AppDelegate()
let app = NSApplication.shared
app.delegate = delegate
app.run()
