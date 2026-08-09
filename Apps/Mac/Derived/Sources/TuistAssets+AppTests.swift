// swiftlint:disable:this file_name
// swiftlint:disable all
// swift-format-ignore-file
// swiftformat:disable all
// Generated using tuist — https://github.com/tuist/tuist



#if os(macOS)
#if hasFeature(InternalImportsByDefault)
public import AppKit
#else
import AppKit
#endif
#else
#if hasFeature(InternalImportsByDefault)
public import UIKit
#else
import UIKit
#endif
#endif

#if canImport(SwiftUI)
#if hasFeature(InternalImportsByDefault)
public import SwiftUI
#else
import SwiftUI
#endif
#endif

// MARK: - Asset Catalogs

public enum AppTestsAsset: Sendable {
  public static let appLogo = AppTestsImages(name: "AppLogo")
  public static let menuBarIcon = AppTestsImages(name: "MenuBarIcon")
  public static let providerDeepseek = AppTestsImages(name: "Provider_deepseek")
  public static let providerDmxapi = AppTestsImages(name: "Provider_dmxapi")
  public static let providerKimi = AppTestsImages(name: "Provider_kimi")
  public static let providerLaozhang = AppTestsImages(name: "Provider_laozhang")
  public static let providerMimo = AppTestsImages(name: "Provider_mimo")
  public static let providerMinimax = AppTestsImages(name: "Provider_minimax")
  public static let providerNewapi = AppTestsImages(name: "Provider_newapi")
  public static let providerOpenrouter = AppTestsImages(name: "Provider_openrouter")
  public static let providerViraltok = AppTestsImages(name: "Provider_viraltok")
  public static let providerVolcengine = AppTestsImages(name: "Provider_volcengine")
}

// MARK: - Implementation Details

public struct AppTestsImages: Sendable {
  public let name: String

  #if os(macOS)
  public typealias Image = NSImage
  #elseif os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
  public typealias Image = UIImage
  #endif

  public var image: Image {
    let bundle = Bundle.module
    #if os(iOS) || os(tvOS) || os(visionOS)
    let image = Image(named: name, in: bundle, compatibleWith: nil)
    #elseif os(macOS)
    let image = bundle.image(forResource: NSImage.Name(name))
    #elseif os(watchOS)
    let image = Image(named: name)
    #endif
    guard let result = image else {
      fatalError("Unable to load image asset named \(name).")
    }
    return result
  }

  #if canImport(SwiftUI)
  @available(iOS 13.0, tvOS 13.0, watchOS 6.0, macOS 10.15, visionOS 1.0, *)
  public var swiftUIImage: SwiftUI.Image {
    SwiftUI.Image(asset: self)
  }
  #endif
}

#if canImport(SwiftUI)
@available(iOS 13.0, tvOS 13.0, watchOS 6.0, macOS 10.15, visionOS 1.0, *)
public extension SwiftUI.Image {
  init(asset: AppTestsImages) {
    let bundle = Bundle.module
    self.init(asset.name, bundle: bundle)
  }

  init(asset: AppTestsImages, label: Text) {
    let bundle = Bundle.module
    self.init(asset.name, bundle: bundle, label: label)
  }

  init(decorative asset: AppTestsImages) {
    let bundle = Bundle.module
    self.init(decorative: asset.name, bundle: bundle)
  }
}
#endif

// swiftformat:enable all
// swiftlint:enable all
