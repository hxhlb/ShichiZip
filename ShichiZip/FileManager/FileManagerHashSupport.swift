import Foundation

enum FileManagerHashAlgorithm {
    case all
    case crc32
    case crc64
    case xxh64
    case md5
    case sha1
    case sha256
    case sha384
    case sha512
    case sha3256
    case blake2sp

    private struct Definition {
        let algorithm: FileManagerHashAlgorithm
        let title: String
        let bridgeName: String
    }

    private static let orderedDefinitions: [Definition] = [
        Definition(algorithm: .crc32, title: "CRC-32", bridgeName: "CRC32"),
        Definition(algorithm: .crc64, title: "CRC-64", bridgeName: "CRC64"),
        Definition(algorithm: .xxh64, title: "XXH64", bridgeName: "XXH64"),
        Definition(algorithm: .md5, title: "MD5", bridgeName: "MD5"),
        Definition(algorithm: .sha1, title: "SHA-1", bridgeName: "SHA1"),
        Definition(algorithm: .sha256, title: "SHA-256", bridgeName: "SHA256"),
        Definition(algorithm: .sha384, title: "SHA-384", bridgeName: "SHA384"),
        Definition(algorithm: .sha512, title: "SHA-512", bridgeName: "SHA512"),
        Definition(algorithm: .sha3256, title: "SHA3-256", bridgeName: "SHA3-256"),
        Definition(algorithm: .blake2sp, title: "BLAKE2sp", bridgeName: "BLAKE2sp"),
    ]

    private static let definitionsByAlgorithm: [FileManagerHashAlgorithm: Definition] = {
        let allDefinition = Definition(algorithm: .all, title: "*", bridgeName: "*")
        let definitions = [allDefinition] + orderedDefinitions
        return Dictionary(uniqueKeysWithValues: definitions.map { ($0.algorithm, $0) })
    }()

    private var definition: Definition {
        Self.definitionsByAlgorithm[self]!
    }

    private var displayedAlgorithms: [FileManagerHashAlgorithm] {
        switch self {
        case .all:
            Self.orderedDefinitions.map(\.algorithm)
        default:
            [self]
        }
    }

    private var title: String {
        definition.title
    }

    private var bridgeName: String {
        definition.bridgeName
    }

    func details(hashValues: [String: String]) -> String {
        displayedAlgorithms
            .map { currentAlgorithm in
                let value = hashValues[currentAlgorithm.bridgeName] ?? "unavailable"
                return "\(currentAlgorithm.title): \(value)"
            }
            .joined(separator: "\n")
    }
}
