//
//  Tuple.swift
//  swift-file-tree
//
//  Created by Woodrow Melling on 12/5/24.
//

import Foundation

public struct TupleFileSystemComponent<each T: FileTreeComponent>: FileTreeComponent {
    public var value: (repeat each T)

    @inlinable public init(_ value: repeat each T) {
        self.value = (repeat each value)
    }

    public typealias Content = (repeat (each T).Content)

    public func read(from url: URL) throws -> Content {
        try (repeat (each value).read(from: url))
    }

    public func write(_ data: (repeat (each T).Content), to url: URL) throws {
        try (repeat (each value).write((each data), to: url))
    }
}
