import AppKit
import XCTest

@MainActor
final class MenuBarStatusItemDriverTests: XCTestCase {
    func testAttachedStatusButtonUsesNonTemplateImage() throws {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        defer { NSStatusBar.system.removeStatusItem(statusItem) }

        MenuBarStatusItemDriver().attach(statusItem)

        let button = try XCTUnwrap(statusItem.button)
        let image = try XCTUnwrap(button.image)
        XCTAssertFalse(image.isTemplate)
        XCTAssertTrue(button.isTransparent)
        XCTAssertGreaterThan(image.size.width, 0)
        XCTAssertGreaterThan(image.size.height, 0)
    }

    func testStatusButtonImageWipeIsRestoredSynchronously() throws {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        defer { NSStatusBar.system.removeStatusItem(statusItem) }

        let driver = MenuBarStatusItemDriver()
        driver.attach(statusItem)

        let button = try XCTUnwrap(statusItem.button)
        let ownedImage = try XCTUnwrap(button.image)
        button.image = NSImage(size: NSSize(width: 1, height: 1))

        XCTAssertTrue(button.image === ownedImage)
    }

    func testReassertPresentationPreservesOwnedImageWhenAppearanceIsUnchanged() throws {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        defer { NSStatusBar.system.removeStatusItem(statusItem) }

        let driver = MenuBarStatusItemDriver()
        driver.attach(statusItem)
        let firstImage = try XCTUnwrap(statusItem.button?.image)

        driver.reassertPresentation()

        XCTAssertTrue(statusItem.button?.image === firstImage)
    }

    func testStatusItemHostWindowBackgroundIsCleared() throws {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        defer { NSStatusBar.system.removeStatusItem(statusItem) }

        MenuBarStatusItemDriver().attach(statusItem)

        let hostWindow = try XCTUnwrap(statusItem.button?.window)
        MenuBarStatusItemDriver.configureHostWindowForTransparency(hostWindow)

        XCTAssertFalse(hostWindow.isOpaque)
        XCTAssertEqual(hostWindow.backgroundColor?.alphaComponent ?? 1, 0, accuracy: 0.01)
        XCTAssertEqual(
            hostWindow.contentView?.layer?.backgroundColor?.alpha ?? 1,
            0,
            accuracy: 0.01
        )
    }

    func testProductAppearanceSkipsStatusBarHostWindow() throws {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        defer { NSStatusBar.system.removeStatusItem(statusItem) }

        let hostWindow = try XCTUnwrap(statusItem.button?.window)
        XCTAssertTrue(MenuBarStatusItemDriver.isStatusBarHostWindow(hostWindow))

        let contentWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 20, height: 20),
            styleMask: .borderless,
            backing: .buffered,
            defer: true
        )
        XCTAssertFalse(MenuBarStatusItemDriver.isStatusBarHostWindow(contentWindow))
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
