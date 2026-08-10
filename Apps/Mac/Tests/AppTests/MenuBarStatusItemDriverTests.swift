import AppKit
import XCTest

@MainActor
final class MenuBarStatusItemDriverTests: XCTestCase {
    func testDefaultMenuBarLabelImageIsColorfulBitmap() throws {
        let source = NSImage(size: NSSize(width: 64, height: 64), flipped: false) { rect in
            NSColor.systemBlue.setFill()
            NSBezierPath(ovalIn: rect.insetBy(dx: 8, dy: 8)).fill()
            return true
        }
        let image = MenuBarStatusItemDriver.makeCurrentBrandLogoImage(from: source, preferDark: false)

        XCTAssertFalse(image.isTemplate)
        let bitmapRepresentation = try XCTUnwrap(
            image.representations.compactMap { $0 as? NSBitmapImageRep }.first,
            "The default menu bar label must use the color bitmap instead of an SF Symbol."
        )
        XCTAssertTrue(bitmapRepresentation.hasAlpha)
    }

    func testHostWindowTransparencyHelperClearsLoadingBackground() throws {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 36, height: 24),
            styleMask: .borderless,
            backing: .buffered,
            defer: true
        )
        window.isOpaque = true
        window.backgroundColor = .white
        let contentView = try XCTUnwrap(window.contentView)
        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = NSColor.white.cgColor

        MenuBarStatusItemDriver.configureHostWindowForTransparency(window)

        XCTAssertFalse(window.isOpaque)
        XCTAssertEqual(window.backgroundColor?.alphaComponent ?? 1, 0, accuracy: 0.01)
        XCTAssertEqual(contentView.layer?.backgroundColor?.alpha ?? 1, 0, accuracy: 0.01)
    }

    func testStatusButtonDoesNotDrawItsOwnBackground() throws {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        defer { NSStatusBar.system.removeStatusItem(statusItem) }

        MenuBarStatusItemDriver().attach(statusItem)

        let button = try XCTUnwrap(statusItem.button)
        XCTAssertTrue(button.isTransparent)

        let hostWindow = try XCTUnwrap(button.window)
        XCTAssertFalse(hostWindow.isOpaque)
        XCTAssertEqual(hostWindow.backgroundColor?.alphaComponent ?? 1, 0, accuracy: 0.01)

        let contentView = try XCTUnwrap(hostWindow.contentView)
        XCTAssertEqual(contentView.layer?.backgroundColor?.alpha ?? 1, 0, accuracy: 0.01)
    }

    func testColorLogoUsesAlphaBackedBitmapRepresentation() throws {
        let sourceRepresentation = try XCTUnwrap(NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: 64,
            pixelsHigh: 64,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ))
        sourceRepresentation.size = NSSize(width: 64, height: 64)
        let sourceContext = try XCTUnwrap(NSGraphicsContext(bitmapImageRep: sourceRepresentation))
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = sourceContext
        sourceContext.cgContext.clear(CGRect(x: 0, y: 0, width: 64, height: 64))
        NSColor.systemBlue.setFill()
        NSBezierPath(ovalIn: NSRect(x: 8, y: 8, width: 48, height: 48)).fill()
        NSGraphicsContext.restoreGraphicsState()

        let source = NSImage(size: NSSize(width: 64, height: 64))
        source.addRepresentation(sourceRepresentation)
        let image = MenuBarStatusItemDriver.makeAlphaBackedColorImage(from: source)
        XCTAssertFalse(image.isTemplate)
        let bitmapRepresentation = try XCTUnwrap(
            image.representations.compactMap { $0 as? NSBitmapImageRep }.first,
            "The colorful status item image must use an explicit bitmap representation."
        )
        XCTAssertTrue(bitmapRepresentation.hasAlpha)
        let cornerAlpha = try XCTUnwrap(bitmapRepresentation.colorAt(x: 0, y: 0)?.alphaComponent)
        XCTAssertEqual(cornerAlpha, 0, accuracy: 0.01)
    }
}
