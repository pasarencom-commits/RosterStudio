import Foundation

/// The kind of work a shift requires. Roles are plain identifiers so a host
/// app can map them onto its own catalogue, localisation, or pay bands.
public struct Role: Hashable, Codable, Sendable, ExpressibleByStringLiteral, CustomStringConvertible {
    public let id: String

    public init(_ id: String) {
        self.id = id
    }

    public init(id: String) {
        self.id = id
    }

    public init(stringLiteral value: String) {
        self.id = value
    }

    public var description: String { id }
}
