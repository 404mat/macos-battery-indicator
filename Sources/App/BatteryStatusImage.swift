import AppKit
import BatteryCore
import BatteryUI

/// A native status-item image is mirrored by AppKit on every menu bar. Keeping
/// the live SwiftUI view out of NSStatusBarButton avoids stale snapshots and
/// layout changes when focus moves between displays.
enum BatteryStatusImage {
    private static let imageHeight: CGFloat = 18
    private static let boltWidth: CGFloat = 11
    private static let boltHeight: CGFloat = 17

    static func make(level: Int, mode: ChargingMode) -> NSImage {
        let size = NSSize(
            width: BatteryIndicatorView.Metrics.width,
            height: imageHeight
        )
        let clampedLevel = min(max(level, 0), 100)
        let image = NSImage(size: size, flipped: true) { bounds in
            draw(in: bounds, level: clampedLevel, mode: mode)
            return true
        }
        image.isTemplate = false
        image.accessibilityDescription = accessibilityDescription(level: clampedLevel, mode: mode)
        return image
    }

    private static func draw(in bounds: NSRect, level: Int, mode: ChargingMode) {
        let metrics = BatteryIndicatorView.Metrics.self
        let bodyWidth = metrics.width - metrics.knobGap - metrics.knobWidth
        let origin = NSPoint(
            x: bounds.midX - metrics.width / 2,
            y: bounds.midY - metrics.height / 2
        )
        let bodyRect = NSRect(
            x: origin.x,
            y: origin.y,
            width: bodyWidth,
            height: metrics.height
        )
        let bodyPath = NSBezierPath(
            roundedRect: bodyRect,
            xRadius: metrics.cornerRadius,
            yRadius: metrics.cornerRadius
        )
        let trackColor = NSColor.labelColor.withAlphaComponent(0.35)

        trackColor.setFill()
        bodyPath.fill()

        NSGraphicsContext.saveGraphicsState()
        bodyPath.addClip()
        fillColor(level: level, mode: mode).setFill()
        NSBezierPath(
            rect: NSRect(
                x: bodyRect.minX,
                y: bodyRect.minY,
                width: bodyRect.width * CGFloat(level) / 100,
                height: bodyRect.height
            )
        ).fill()
        NSGraphicsContext.restoreGraphicsState()

        let knobRect = NSRect(
            x: bodyRect.maxX + metrics.knobGap,
            y: bounds.midY - metrics.knobHeight / 2,
            width: metrics.knobWidth,
            height: metrics.knobHeight
        )
        trackColor.setFill()
        knobPath(in: knobRect).fill()

        if mode == .charging {
            let boltRect = NSRect(
                x: bounds.midX + metrics.bodyCenterOffsetX - boltWidth / 2,
                y: bounds.midY - boltHeight / 2,
                width: boltWidth,
                height: boltHeight
            )
            let bolt = boltPath(in: boltRect)

            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current?.compositingOperation = .clear
            bolt.fill()
            bolt.lineWidth = 3
            bolt.lineJoinStyle = .round
            bolt.stroke()
            NSGraphicsContext.restoreGraphicsState()

            NSColor.labelColor.setFill()
            bolt.fill()
        } else if mode == .error {
            drawErrorSymbol(centeredAt: NSPoint(x: bounds.midX - 1, y: bounds.midY))
        }
    }

    private static func fillColor(level: Int, mode: ChargingMode) -> NSColor {
        if mode == .charging {
            return .systemGreen
        }
        return level <= 10 ? .systemRed : .labelColor
    }

    private static func knobPath(in rect: NSRect) -> NSBezierPath {
        let path = NSBezierPath()
        path.move(to: NSPoint(x: rect.minX, y: rect.minY))
        path.curve(
            to: NSPoint(x: rect.minX, y: rect.maxY),
            controlPoint1: NSPoint(x: rect.minX + rect.width * 4 / 3, y: rect.minY),
            controlPoint2: NSPoint(x: rect.minX + rect.width * 4 / 3, y: rect.maxY)
        )
        path.close()
        return path
    }

    private static func boltPath(in rect: NSRect) -> NSBezierPath {
        let points = [
            NSPoint(x: rect.minX + rect.width * 0.68, y: rect.minY),
            NSPoint(x: rect.minX + rect.width * 0.02, y: rect.minY + rect.height * 0.57),
            NSPoint(x: rect.minX + rect.width * 0.44, y: rect.minY + rect.height * 0.57),
            NSPoint(x: rect.minX + rect.width * 0.27, y: rect.maxY),
            NSPoint(x: rect.minX + rect.width * 0.98, y: rect.minY + rect.height * 0.39),
            NSPoint(x: rect.minX + rect.width * 0.62, y: rect.minY + rect.height * 0.39),
        ]
        let cornerOffset = min(rect.width, rect.height) * 0.075
        let path = NSBezierPath()

        for index in points.indices {
            let point = points[index]
            let previous = points[(index + points.count - 1) % points.count]
            let next = points[(index + 1) % points.count]
            let beforeCorner = offsetPoint(from: point, toward: previous, by: cornerOffset)
            let afterCorner = offsetPoint(from: point, toward: next, by: cornerOffset)

            if index == points.startIndex {
                path.move(to: beforeCorner)
            } else {
                path.line(to: beforeCorner)
            }
            path.curve(to: afterCorner, controlPoint1: point, controlPoint2: point)
        }

        path.close()
        return path
    }

    private static func offsetPoint(
        from point: NSPoint,
        toward target: NSPoint,
        by distance: CGFloat
    ) -> NSPoint {
        let deltaX = target.x - point.x
        let deltaY = target.y - point.y
        let length = hypot(deltaX, deltaY)
        guard length > 0 else { return point }

        let offset = min(distance, length / 2)
        return NSPoint(
            x: point.x + deltaX / length * offset,
            y: point.y + deltaY / length * offset
        )
    }

    private static func drawErrorSymbol(centeredAt center: NSPoint) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11, weight: .semibold),
            .foregroundColor: NSColor.systemRed,
        ]
        let symbol = NSAttributedString(string: "!", attributes: attributes)
        let size = symbol.size()
        symbol.draw(at: NSPoint(x: center.x - size.width / 2, y: center.y - size.height / 2))
    }

    private static func accessibilityDescription(level: Int, mode: ChargingMode) -> String {
        switch mode {
        case .charging:
            return "Battery charging, \(level) percent"
        case .pluggedIn:
            return "Battery plugged in, \(level) percent"
        case .discharging:
            return "Battery, \(level) percent"
        case .error:
            return "Battery status unavailable"
        }
    }
}
