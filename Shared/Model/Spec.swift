import Foundation

/// One row in a watch's spec sheet, e.g. "Case size" / "41 mm".
struct Spec: Codable, Hashable, Identifiable {
    var label: String
    var value: String

    var id: String { label }
}
