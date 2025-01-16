//
//  FileExtension.swift
//  swift-file-tree
//
//  Created by Woodrow Melling on 12/5/24.
//

import Foundation

public struct FileExtension: ExpressibleByStringLiteral, Sendable, Hashable {
    var rawValue: String

    public init(stringLiteral value: StringLiteralType) {
        self.rawValue = value
    }
}

extension URL {
    func appendingPathComponent(_ partialName: String, withType type: FileExtension) -> URL {
        self.appending(path: partialName).appendingPathExtension(partialName)
    }
}
