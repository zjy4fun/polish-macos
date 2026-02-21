import AppKit

enum PolishBrandIcon {
    static func appIcon(size: CGFloat = 512) -> NSImage? {
        guard size > 0 else { return nil }
        let iconSize = NSSize(width: size, height: size)
        let image = NSImage(size: iconSize)

        image.lockFocus()
        defer { image.unlockFocus() }

        let canvas = NSRect(origin: .zero, size: iconSize)
        let cornerRadius = size * 0.225
        let backgroundPath = NSBezierPath(roundedRect: canvas, xRadius: cornerRadius, yRadius: cornerRadius)

        let backgroundGradient = NSGradient(
            colorsAndLocations:
                (NSColor(srgbRed: 0.05, green: 0.30, blue: 0.85, alpha: 1.0), 0.0),
                (NSColor(srgbRed: 0.08, green: 0.62, blue: 0.84, alpha: 1.0), 0.56),
                (NSColor(srgbRed: 0.94, green: 0.62, blue: 0.18, alpha: 1.0), 1.0)
        )
        backgroundGradient?.draw(in: backgroundPath, angle: -38)

        NSColor(calibratedWhite: 1.0, alpha: 0.22).setFill()
        NSBezierPath(ovalIn: NSRect(x: size * 0.02, y: size * 0.52, width: size * 0.56, height: size * 0.56)).fill()

        NSColor(calibratedWhite: 0.05, alpha: 0.16).setFill()
        NSBezierPath(ovalIn: NSRect(x: size * 0.46, y: -size * 0.06, width: size * 0.62, height: size * 0.62)).fill()

        NSColor(calibratedWhite: 1.0, alpha: 0.24).setStroke()
        backgroundPath.lineWidth = max(2, size * 0.008)
        backgroundPath.stroke()

        drawPolishDocumentCard(size: size)
        drawPolishStars(size: size)

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

    private static func drawPolishDocumentCard(size: CGFloat) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.saveGState()
        defer { context.restoreGState() }

        context.translateBy(x: size * 0.5, y: size * 0.5)
        context.rotate(by: -.pi * 0.09)

        let cardRect = CGRect(x: -size * 0.28, y: -size * 0.31, width: size * 0.56, height: size * 0.66)
        let cardPath = CGPath(
            roundedRect: cardRect,
            cornerWidth: size * 0.07,
            cornerHeight: size * 0.07,
            transform: nil
        )

        context.setShadow(
            offset: CGSize(width: size * 0.01, height: -size * 0.022),
            blur: size * 0.04,
            color: NSColor(calibratedWhite: 0.0, alpha: 0.24).cgColor
        )
        context.addPath(cardPath)
        context.clip()

        let cardGradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: [
                NSColor(calibratedWhite: 1.0, alpha: 0.95).cgColor,
                NSColor(srgbRed: 0.93, green: 0.97, blue: 1.0, alpha: 0.90).cgColor,
            ] as CFArray,
            locations: [0.0, 1.0]
        )
        context.drawLinearGradient(
            cardGradient!,
            start: CGPoint(x: cardRect.minX, y: cardRect.maxY),
            end: CGPoint(x: cardRect.maxX, y: cardRect.minY),
            options: []
        )

        context.resetClip()
        context.setShadow(offset: .zero, blur: 0, color: nil)
        context.addPath(cardPath)
        context.setStrokeColor(NSColor(calibratedWhite: 1.0, alpha: 0.62).cgColor)
        context.setLineWidth(max(1.5, size * 0.008))
        context.strokePath()

        context.setStrokeColor(NSColor(srgbRed: 0.18, green: 0.33, blue: 0.62, alpha: 0.3).cgColor)
        context.setLineWidth(max(1.5, size * 0.009))
        context.setLineCap(.round)

        let lineStart = cardRect.minX + size * 0.07
        let firstY = cardRect.maxY - size * 0.16
        for index in 0..<3 {
            let y = firstY - CGFloat(index) * size * 0.1
            let lineLength = size * (index == 2 ? 0.24 : 0.35)
            context.move(to: CGPoint(x: lineStart, y: y))
            context.addLine(to: CGPoint(x: lineStart + lineLength, y: y))
            context.strokePath()
        }

        let polishPath = CGMutablePath()
        polishPath.move(to: CGPoint(x: cardRect.minX + size * 0.08, y: cardRect.minY + size * 0.17))
        polishPath.addQuadCurve(
            to: CGPoint(x: cardRect.minX + size * 0.25, y: cardRect.minY + size * 0.20),
            control: CGPoint(x: cardRect.minX + size * 0.17, y: cardRect.minY + size * 0.14)
        )
        polishPath.addQuadCurve(
            to: CGPoint(x: cardRect.minX + size * 0.41, y: cardRect.minY + size * 0.30),
            control: CGPoint(x: cardRect.minX + size * 0.32, y: cardRect.minY + size * 0.23)
        )

        context.addPath(polishPath)
        context.setStrokeColor(NSColor(srgbRed: 0.05, green: 0.45, blue: 0.87, alpha: 0.92).cgColor)
        context.setLineWidth(max(2.5, size * 0.024))
        context.setLineCap(.round)
        context.setLineJoin(.round)
        context.strokePath()
    }

    private static func drawPolishStars(size: CGFloat) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }

        context.setFillColor(NSColor(calibratedWhite: 1.0, alpha: 0.97).cgColor)
        drawStar(
            context: context,
            center: CGPoint(x: size * 0.76, y: size * 0.72),
            outerRadius: size * 0.075,
            innerRadius: size * 0.03,
            points: 4
        )

        context.setFillColor(NSColor(srgbRed: 1.0, green: 0.93, blue: 0.78, alpha: 0.98).cgColor)
        drawStar(
            context: context,
            center: CGPoint(x: size * 0.82, y: size * 0.58),
            outerRadius: size * 0.04,
            innerRadius: size * 0.016,
            points: 4
        )
    }
}
