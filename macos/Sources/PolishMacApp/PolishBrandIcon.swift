import AppKit

enum PolishBrandIcon {
    static func appIcon(size: CGFloat = 512) -> NSImage? {
        guard size > 0 else { return nil }
        let iconSize = NSSize(width: size, height: size)
        let image = NSImage(size: iconSize)

        image.lockFocus()
        defer { image.unlockFocus() }

        let canvas = NSRect(origin: .zero, size: iconSize)
        let cornerRadius = size * 0.22
        let backgroundPath = NSBezierPath(roundedRect: canvas, xRadius: cornerRadius, yRadius: cornerRadius)

        let gradient = NSGradient(
            colorsAndLocations:
                (NSColor(srgbRed: 0.05, green: 0.35, blue: 0.86, alpha: 1.0), 0.0),
                (NSColor(srgbRed: 0.08, green: 0.69, blue: 0.68, alpha: 1.0), 0.58),
                (NSColor(srgbRed: 0.95, green: 0.63, blue: 0.21, alpha: 1.0), 1.0)
        )
        gradient?.draw(in: backgroundPath, angle: -35)

        let lightSpot = NSRect(x: size * 0.1, y: size * 0.54, width: size * 0.58, height: size * 0.58)
        NSColor(calibratedWhite: 1.0, alpha: 0.15).setFill()
        NSBezierPath(ovalIn: lightSpot).fill()

        let ringRect = NSRect(x: size * 0.28, y: size * 0.2, width: size * 0.56, height: size * 0.56)
        NSColor(calibratedWhite: 1.0, alpha: 0.22).setStroke()
        let ringPath = NSBezierPath(ovalIn: ringRect)
        ringPath.lineWidth = max(2, size * 0.026)
        ringPath.stroke()

        drawWandAndStars(in: canvas, size: size)

        return image
    }

    static func statusBarIcon(pointSize: CGFloat = 15) -> NSImage? {
        let side = max(18, pointSize + 4)
        let image = NSImage(size: NSSize(width: side, height: side))
        image.lockFocus()
        defer { image.unlockFocus() }

        let outer = NSRect(x: 0, y: 0, width: side, height: side)
        let circle = NSBezierPath(ovalIn: outer)
        let gradient = NSGradient(
            colorsAndLocations:
                (NSColor(srgbRed: 0.08, green: 0.43, blue: 0.89, alpha: 1.0), 0.0),
                (NSColor(srgbRed: 0.11, green: 0.71, blue: 0.69, alpha: 1.0), 1.0)
        )
        gradient?.draw(in: circle, angle: -35)

        let inner = NSRect(x: side * 0.3, y: side * 0.3, width: side * 0.4, height: side * 0.4)
        NSColor.white.setFill()
        NSBezierPath(ovalIn: inner).fill()

        image.isTemplate = false
        return image
    }

    private static func drawWandAndStars(in canvas: NSRect, size: CGFloat) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }

        context.saveGState()
        context.translateBy(x: canvas.midX, y: canvas.midY)
        context.rotate(by: -.pi / 4)
        context.setFillColor(NSColor.white.cgColor)

        let wandRect = CGRect(
            x: -size * 0.2,
            y: -size * 0.035,
            width: size * 0.42,
            height: size * 0.105
        )
        let wand = CGPath(
            roundedRect: wandRect,
            cornerWidth: size * 0.048,
            cornerHeight: size * 0.048,
            transform: nil
        )
        context.addPath(wand)
        context.fillPath()
        context.restoreGState()

        context.setFillColor(NSColor.white.cgColor)
        drawStar(
            context: context,
            center: CGPoint(x: size * 0.66, y: size * 0.7),
            outerRadius: size * 0.08,
            innerRadius: size * 0.034,
            points: 4
        )
        drawStar(
            context: context,
            center: CGPoint(x: size * 0.73, y: size * 0.58),
            outerRadius: size * 0.044,
            innerRadius: size * 0.018,
            points: 4
        )
    }

    private static func drawStar(
        context: CGContext,
        center: CGPoint,
        outerRadius: CGFloat,
        innerRadius: CGFloat,
        points: Int
    ) {
        guard points > 1 else { return }
        let path = CGMutablePath()
        let step = .pi / CGFloat(points)

        for index in 0..<(points * 2) {
            let radius = index.isMultiple(of: 2) ? outerRadius : innerRadius
            let angle = CGFloat(index) * step - .pi / 2
            let point = CGPoint(
                x: center.x + cos(angle) * radius,
                y: center.y + sin(angle) * radius
            )
            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()
        context.addPath(path)
        context.fillPath()
    }
}
