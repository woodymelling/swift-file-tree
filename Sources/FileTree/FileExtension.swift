//
//  FileExtension.swift
//  swift-file-tree
//
//  Created by Woodrow Melling on 12/5/24.
//

import UniformTypeIdentifiers
import Foundation

enum UTFileExtension: Sendable, Hashable {
    case utType(UTType)
    case `extension`(FileExtension)

    var identifier: String {
        switch self {
        case .utType(let utType):
            utType.identifier
        case .extension(let e):
            e.rawValue
        }
    }
}

public struct FileExtension: ExpressibleByStringLiteral, Sendable, Hashable {
    var rawValue: String

    public init(stringLiteral value: StringLiteralType) {
        self.rawValue = value
    }
}

extension URL {
    func appendingPathComponent(_ partialName: String, withType type: UTFileExtension) -> URL {
        switch type {
        case .utType(let utType):
            self.appendingPathComponent(partialName, conformingTo: utType)
        case .extension(let string):
            self.appending(path: partialName).appendingPathExtension(string.rawValue)
        }
    }
}
