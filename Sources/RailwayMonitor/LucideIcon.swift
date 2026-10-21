import AppKit

/// A Lucide glyph, transcribed from the upstream SVG.
///
/// Ported from Squiggle's `LucideIcon.swift` (itself from Pitch, from InOut) so
/// the footers of the apps in the menubar carry the same icons drawn the same
/// way: Lucide's 24-unit grid, y pointing down, rendered into a flipped context.
struct LucideIcon {
    /// Appends the glyph in Lucide's own 24-unit space.
    let trace: (NSBezierPath) -> Void

    static let grid: CGFloat = 24
    /// Lucide's own stroke width, in grid units.
    static let strokeUnits: CGFloat = 2

    /// lucide/icons/refresh-cw.svg — identical to Squiggle's transcription
    /// (both ring halves as plain 9-radius arcs; the difference from upstream
    /// is a fifth of a pixel at 13pt).
    static var refreshCw: LucideIcon {
        LucideIcon { path in
            path.appendArc(withCenter: CGPoint(x: 12, y: 12), radius: 9,
                           startAngle: 180, endAngle: 317, clockwise: false)
            path.line(to: CGPoint(x: 21, y: 8))

            path.move(to: CGPoint(x: 21, y: 3))
            path.line(to: CGPoint(x: 21, y: 8))
            path.line(to: CGPoint(x: 16, y: 8))

            path.move(to: CGPoint(x: 21, y: 12))
            path.appendArc(withCenter: CGPoint(x: 12, y: 12), radius: 9,
                           startAngle: 0, endAngle: 137, clockwise: false)
            path.line(to: CGPoint(x: 3, y: 16))

            path.move(to: CGPoint(x: 8, y: 16))
            path.line(to: CGPoint(x: 3, y: 16))
            path.line(to: CGPoint(x: 3, y: 21))
        }
    }

    /// lucide/icons/coffee.svg — identical to Squiggle's transcription.
    static var coffee: LucideIcon {
        LucideIcon { path in
            // "M16 8a1 1 0 0 1 1 1v8a4 4 0 0 1-4 4H7a4 4 0 0 1-4-4V9a1 1 0 0 1
            //  1-1h14a4 4 0 1 1 0 8h-1" — the cup, as tangent arcs.
            path.move(to: CGPoint(x: 16, y: 8))
            path.appendArc(from: CGPoint(x: 17, y: 8), to: CGPoint(x: 17, y: 17), radius: 1)
            path.appendArc(from: CGPoint(x: 17, y: 21), to: CGPoint(x: 7, y: 21), radius: 4)
            path.appendArc(from: CGPoint(x: 3, y: 21), to: CGPoint(x: 3, y: 9), radius: 4)
            path.appendArc(from: CGPoint(x: 3, y: 8), to: CGPoint(x: 18, y: 8), radius: 1)
            path.line(to: CGPoint(x: 18, y: 8))
            // The handle: a half-circle about (18,12), bulging right.
            path.appendArc(withCenter: CGPoint(x: 18, y: 12), radius: 4,
                           startAngle: 270, endAngle: 450, clockwise: false)
            path.line(to: CGPoint(x: 17, y: 16))
            // "M6 2v2", "M10 2v2", "M14 2v2" — steam.
            for x in [6.0, 10.0, 14.0] as [CGFloat] {
                path.move(to: CGPoint(x: x, y: 2))
                path.line(to: CGPoint(x: x, y: 4))
            }
        }
    }

    /// lucide/icons/log-out.svg — identical to Squiggle's.
    static var logOut: LucideIcon {
        LucideIcon { path in
            // "m16 17 5-5-5-5"
            path.move(to: CGPoint(x: 16, y: 17))
            path.line(to: CGPoint(x: 21, y: 12))
            path.line(to: CGPoint(x: 16, y: 7))
            // "M21 12H9"
            path.move(to: CGPoint(x: 21, y: 12))
            path.line(to: CGPoint(x: 9, y: 12))
            // "M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4"
            path.move(to: CGPoint(x: 9, y: 21))
            path.appendArc(from: CGPoint(x: 3, y: 21), to: CGPoint(x: 3, y: 5), radius: 2)
            path.appendArc(from: CGPoint(x: 3, y: 3), to: CGPoint(x: 9, y: 3), radius: 2)
            path.line(to: CGPoint(x: 9, y: 3))
        }
    }

    /// lucide/icons/external-link.svg — opens status.railway.com.
    static var externalLink: LucideIcon {
        LucideIcon { path in
            // "M15 3h6v6" — the arrowhead corner.
            path.move(to: CGPoint(x: 15, y: 3))
            path.line(to: CGPoint(x: 21, y: 3))
            path.line(to: CGPoint(x: 21, y: 9))
            // "M10 14 21 3" — the shaft.
            path.move(to: CGPoint(x: 10, y: 14))
            path.line(to: CGPoint(x: 21, y: 3))
            // "M18 13v6a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h6" — the box.
            path.move(to: CGPoint(x: 18, y: 13))
            path.appendArc(from: CGPoint(x: 18, y: 21), to: CGPoint(x: 5, y: 21), radius: 2)
            path.appendArc(from: CGPoint(x: 3, y: 21), to: CGPoint(x: 3, y: 8), radius: 2)
            path.appendArc(from: CGPoint(x: 3, y: 6), to: CGPoint(x: 11, y: 6), radius: 2)
            path.line(to: CGPoint(x: 11, y: 6))
        }
    }

    /// lucide/icons/check-check.svg — "track all groups again".
    static var checkCheck: LucideIcon {
        LucideIcon { path in
            // "M18 6 7 17l-5-5"
            path.move(to: CGPoint(x: 18, y: 6))
            path.line(to: CGPoint(x: 7, y: 17))
            path.line(to: CGPoint(x: 2, y: 12))
            // "m22 10-7.5 7.5L13 16"
            path.move(to: CGPoint(x: 22, y: 10))
            path.line(to: CGPoint(x: 14.5, y: 17.5))
            path.line(to: CGPoint(x: 13, y: 16))
        }
    }

    // MARK: Status symbols (Settings → Monochrome icons)

    /// Lucide's circle outline: `<circle cx="12" cy="12" r="10"/>`.
    private static func ring(_ path: NSBezierPath) {
        path.appendOval(in: NSRect(x: 2, y: 2, width: 20, height: 20))
    }

    /// lucide/icons/circle-check.svg — operational.
    static var circleCheck: LucideIcon {
        LucideIcon { path in
            ring(path)
            // "m9 12 2 2 4-4"
            path.move(to: CGPoint(x: 9, y: 12))
            path.line(to: CGPoint(x: 11, y: 14))
            path.line(to: CGPoint(x: 15, y: 10))
        }
    }

    /// lucide/icons/circle-alert.svg — partial outage / degraded.
    static var circleAlert: LucideIcon {
        LucideIcon { path in
            ring(path)
            // "M12 8v4" and "M12 16h.01" (the dot: a near-zero line with a round cap)
            path.move(to: CGPoint(x: 12, y: 8))
            path.line(to: CGPoint(x: 12, y: 12))
            path.move(to: CGPoint(x: 12, y: 16))
            path.line(to: CGPoint(x: 12.01, y: 16))
        }
    }

    /// lucide/icons/circle-x.svg — major outage.
    static var circleX: LucideIcon {
        LucideIcon { path in
            ring(path)
            // "m15 9-6 6" and "m9 9 6 6"
            path.move(to: CGPoint(x: 15, y: 9))
            path.line(to: CGPoint(x: 9, y: 15))
            path.move(to: CGPoint(x: 9, y: 9))
            path.line(to: CGPoint(x: 15, y: 15))
        }
    }

    /// lucide/icons/circle-minus.svg — no data / out of date.
    static var circleMinus: LucideIcon {
        LucideIcon { path in
            ring(path)
            // "M8 12h8"
            path.move(to: CGPoint(x: 8, y: 12))
            path.line(to: CGPoint(x: 16, y: 12))
        }
    }

    /// A template image of this glyph, stroked at `size` points. `weight` 1.15
    /// is InOut/Pitch/Squiggle's optical correction against SF Symbols.
    func image(size: CGFloat, weight: CGFloat = 1.15) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size), flipped: true) { rect in
            guard let context = NSGraphicsContext.current?.cgContext else { return false }
            context.saveGState()
            defer { context.restoreGState() }
            let scale = min(rect.width, rect.height) / LucideIcon.grid
            context.translateBy(x: rect.midX, y: rect.midY)
            context.scaleBy(x: scale, y: scale)
            context.translateBy(x: -LucideIcon.grid / 2, y: -LucideIcon.grid / 2)

            let path = NSBezierPath()
            self.trace(path)
            path.lineWidth = LucideIcon.strokeUnits * weight
            path.lineCapStyle = .round
            path.lineJoinStyle = .round
            NSColor.black.setStroke()
            path.stroke()
            return true
        }
        image.isTemplate = true
        return image
    }

    /// The same glyph as a `CGPath`, for the spinning refresh layer (which sits
    /// in a flipped NSButton's layer, so no flip here — same as Squiggle).
    func cgPath(size: CGFloat) -> CGPath {
        let path = NSBezierPath()
        trace(path)
        let scale = size / LucideIcon.grid
        var toLayer = CGAffineTransform(scaleX: scale, y: scale)
        let traced = path.cgPath
        return traced.copy(using: &toLayer) ?? traced
    }

    static func strokeWidth(size: CGFloat, weight: CGFloat = 1.15) -> CGFloat {
        strokeUnits * weight * (size / grid)
    }
}
