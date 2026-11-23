import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Whether this iPhone can run Apple's on-device model. Saving a watch from a
/// link is only offered where it can; everywhere else watches are added by hand.
enum AppleIntelligence {
    enum Status: Equatable {
        case available
        /// Supported, but switched off in Settings.
        case turnedOff
        /// Switched on and still downloading.
        case gettingReady
        /// This iPhone can't run it.
        case notSupported
    }

    static var status: Status {
        #if DEBUG
        // For screenshots: -CrownsAppleIntelligence available|turnedOff|gettingReady|notSupported
        switch UserDefaults.standard.string(forKey: "CrownsAppleIntelligence") {
        case "available": return .available
        case "turnedOff": return .turnedOff
        case "gettingReady": return .gettingReady
        case "notSupported": return .notSupported
        default: break
        }
        #endif
        #if canImport(FoundationModels)
        switch SystemLanguageModel.default.availability {
        case .available: return .available
        case .unavailable(.appleIntelligenceNotEnabled): return .turnedOff
        case .unavailable(.modelNotReady): return .gettingReady
        default: return .notSupported
        }
        #else
        return .notSupported
        #endif
    }

    static var isAvailable: Bool { status == .available }

    /// Why links can't be read here, in a sentence.
    static var unavailableReason: String {
        switch status {
        case .available: ""
        case .turnedOff: "Turn on Apple Intelligence in Settings to save watches from a link."
        case .gettingReady: "Apple Intelligence is still getting ready. Saving from a link will appear once it's done."
        case .notSupported: "Saving from a link needs an iPhone with Apple Intelligence."
        }
    }
}
