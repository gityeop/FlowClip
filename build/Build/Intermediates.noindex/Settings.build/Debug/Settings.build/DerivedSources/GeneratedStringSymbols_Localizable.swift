// 
// GeneratedStringSymbols_Localizable.swift
// Auto-Generated symbols for localized strings defined in “Localizable.xcstrings”.
// 

import Foundation

#if SWIFT_PACKAGE
private let resourceBundle = Foundation.Bundle.module
@available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
private let resourceBundleDescription = LocalizedStringResource.BundleDescription.atURL(resourceBundle.bundleURL)
#else

private class ResourceBundleClass {}
@available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
private let resourceBundleDescription = LocalizedStringResource.BundleDescription.forClass(ResourceBundleClass.self)
#endif

@available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
extension LocalizedStringResource {
    /**
     Localized string for key “preferences” in table “Localizable.xcstrings”.
     */
    static var preferences: LocalizedStringResource {
        LocalizedStringResource("preferences", table: "Localizable", bundle: resourceBundleDescription)
    }

    /**
     Localized string for key “settings” in table “Localizable.xcstrings”.
     */
    static var settings: LocalizedStringResource {
        LocalizedStringResource("settings", table: "Localizable", bundle: resourceBundleDescription)
    }
}