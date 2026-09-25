import Foundation

extension KeyedDecodingContainer {
    /// Decodes a value for `key`, falling back to `defaultValue` when the key is absent
    /// or its value is `null`. Used throughout ACPKit's model types to reproduce the ACP
    /// schema's documented default values for optional capability/flag fields.
    func decode<T: Decodable>(_ type: T.Type, forKey key: Key, default defaultValue: T) throws -> T {
        try decodeIfPresent(type, forKey: key) ?? defaultValue
    }
}
