import Foundation

/// A small JSON value tree used for compact stable command results.
enum CLIJSONValue: Encodable, Sendable {

    case string(String)
    case boolean(Bool)
    case array([CLIJSONValue])
    case object([String: CLIJSONValue])

    /// Encodes the modeled value through its matching JSON container.
    func encode(to encoder: Encoder) throws {

        var container = encoder.singleValueContainer()
        
        switch self {
            case .string(let value): try container.encode(value)
            case .boolean(let value): try container.encode(value)
            case .array(let value): try container.encode(value)
            case .object(let value): try container.encode(value)
        }
    }

}

/// Machine-readable command result envelope.
struct CLIJSONEnvelope: Encodable {

    let schemaVersion = 1
    
    private(set) var command: String
    private(set) var outcome: String
    private(set) var result: CLIJSONValue? = nil
    private(set) var preparation: CLIJSONValue? = nil
    private(set) var error: CLIJSONValue? = nil

}
