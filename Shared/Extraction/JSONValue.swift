import Foundation

/// Arbitrary JSON, for JSON-LD and Shopify product data whose shape varies by site.
enum JSONValue: Codable, Hashable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() {
            self = .null
        } else if let v = try? c.decode(String.self) {
            self = .string(v)
        } else if let v = try? c.decode(Bool.self) {
            self = .bool(v)
        } else if let v = try? c.decode(Double.self) {
            self = .number(v)
        } else if let v = try? c.decode([String: JSONValue].self) {
            self = .object(v)
        } else if let v = try? c.decode([JSONValue].self) {
            self = .array(v)
        } else {
            self = .null
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .string(let v): try c.encode(v)
        case .number(let v): try c.encode(v)
        case .bool(let v): try c.encode(v)
        case .object(let v): try c.encode(v)
        case .array(let v): try c.encode(v)
        case .null: try c.encodeNil()
        }
    }

    subscript(key: String) -> JSONValue? {
        if case .object(let o) = self { return o[key] }
        return nil
    }

    /// Text value. Numbers are rendered without a trailing ".0".
    /// Objects such as {"@type": "Brand", "name": "Rolex"} yield their name.
    var string: String? {
        switch self {
        case .string(let s):
            let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
            return t.isEmpty ? nil : t
        case .number(let n):
            return n == n.rounded() && abs(n) < 1e15 ? String(Int64(n)) : String(n)
        case .object:
            return self["name"]?.string ?? self["@value"]?.string
        case .array(let a):
            return a.lazy.compactMap(\.string).first
        default:
            return nil
        }
    }

    var double: Double? {
        switch self {
        case .number(let n): return n
        case .string(let s): return PriceParser.number(in: s)
        default: return nil
        }
    }

    /// The value as a list: arrays as they are, a single value wrapped.
    var list: [JSONValue] {
        switch self {
        case .array(let a): return a
        case .null: return []
        default: return [self]
        }
    }

    var isObject: Bool {
        if case .object = self { return true }
        return false
    }
}
