import Foundation

enum BoxFinish: String, CaseIterable, Codable, Identifiable {
    case walnut, ebony, oak, oxblood

    var id: String { rawValue }

    var title: String {
        switch self {
        case .walnut: "Walnut"
        case .ebony: "Ebony"
        case .oak: "Oak"
        case .oxblood: "Oxblood"
        }
    }
}
