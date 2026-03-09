import Foundation
#if canImport(DeveloperToolsSupport)
import DeveloperToolsSupport
#endif

#if SWIFT_PACKAGE
private let resourceBundle = Foundation.Bundle.module
#else
private class ResourceBundleClass {}
private let resourceBundle = Foundation.Bundle(for: ResourceBundleClass.self)
#endif

// MARK: - Color Symbols -

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension DeveloperToolsSupport.ColorResource {

    /// The "AccentColor" asset catalog color resource.
    static let accent = DeveloperToolsSupport.ColorResource(name: "AccentColor", bundle: resourceBundle)

    /// The "CardBorder" asset catalog color resource.
    static let cardBorder = DeveloperToolsSupport.ColorResource(name: "CardBorder", bundle: resourceBundle)

    /// The "CardBorderDark" asset catalog color resource.
    static let cardBorderDark = DeveloperToolsSupport.ColorResource(name: "CardBorderDark", bundle: resourceBundle)

    /// The "CardElevated" asset catalog color resource.
    static let cardElevated = DeveloperToolsSupport.ColorResource(name: "CardElevated", bundle: resourceBundle)

    /// The "CardSurface" asset catalog color resource.
    static let cardSurface = DeveloperToolsSupport.ColorResource(name: "CardSurface", bundle: resourceBundle)

    /// The "PageBg" asset catalog color resource.
    static let pageBg = DeveloperToolsSupport.ColorResource(name: "PageBg", bundle: resourceBundle)

}

// MARK: - Image Symbols -

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension DeveloperToolsSupport.ImageResource {

}

