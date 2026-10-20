import AppKit

func render(_ px: Int) -> Data {
    let s = CGFloat(px)
    let img = NSImage(size: NSSize(width: s, height: s))
    img.lockFocus()
    // Background: rounded square with a deep red-to-purple gradient
    let bg = NSBezierPath(roundedRect: NSRect(x: s*0.06, y: s*0.06, width: s*0.88, height: s*0.88), xRadius: s*0.2, yRadius: s*0.2)
    NSGradient(colors: [NSColor(red: 0.95, green: 0.35, blue: 0.20, alpha: 1), NSColor(red: 0.45, green: 0.10, blue: 0.55, alpha: 1)])!.draw(in: bg, angle: -60)
    // TV body
    let body = NSBezierPath(roundedRect: NSRect(x: s*0.20, y: s*0.30, width: s*0.60, height: s*0.44), xRadius: s*0.06, yRadius: s*0.06)
    NSColor(white: 0.08, alpha: 1).setFill(); body.fill()
    // Screen
    let scr = NSBezierPath(roundedRect: NSRect(x: s*0.235, y: s*0.335, width: s*0.53, height: s*0.37), xRadius: s*0.035, yRadius: s*0.035)
    NSGradient(colors: [NSColor(red: 0.30, green: 0.80, blue: 1.0, alpha: 1), NSColor(red: 0.10, green: 0.35, blue: 0.85, alpha: 1)])!.draw(in: scr, angle: -90)
    // Play triangle
    let t = NSBezierPath()
    t.move(to: NSPoint(x: s*0.45, y: s*0.43)); t.line(to: NSPoint(x: s*0.45, y: s*0.61)); t.line(to: NSPoint(x: s*0.60, y: s*0.52)); t.close()
    NSColor.white.setFill(); t.fill()
    // Antenna
    NSColor(white: 0.95, alpha: 1).setStroke()
    for (dx, ex) in [(0.0, -0.10), (0.0, 0.10)] {
        let a = NSBezierPath(); a.lineWidth = s*0.022; a.lineCapStyle = .round
        a.move(to: NSPoint(x: s*(0.5+dx), y: s*0.74)); a.line(to: NSPoint(x: s*(0.5+ex), y: s*0.86)); a.stroke()
    }
    // Stand
    let stand = NSBezierPath(roundedRect: NSRect(x: s*0.34, y: s*0.24, width: s*0.32, height: s*0.04), xRadius: s*0.02, yRadius: s*0.02)
    NSColor(white: 0.95, alpha: 1).setFill(); stand.fill()
    img.unlockFocus()
    let rep = NSBitmapImageRep(data: img.tiffRepresentation!)!
    return rep.representation(using: .png, properties: [:])!
}

let dir = CommandLine.arguments[1]
for (name, px) in [("16",16),("16@2x",32),("32",32),("32@2x",64),("128",128),("128@2x",256),("256",256),("256@2x",512),("512",512),("512@2x",1024)] {
    try! render(px).write(to: URL(fileURLWithPath: "\(dir)/icon_\(name.replacingOccurrences(of: "@2x", with: ""))x\(name.replacingOccurrences(of: "@2x", with: ""))\(name.contains("@2x") ? "@2x" : "").png"))
}
