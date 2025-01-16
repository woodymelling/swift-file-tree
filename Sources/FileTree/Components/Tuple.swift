//
//  Tuple.swift
//  swift-file-tree
//
//  Created by Woodrow Melling on 12/5/24.
//

import Foundation
//
// public struct TupleFileSystemComponent<each T: FileTreeComponent>: FileTreeComponent {
//     public var value: (repeat each T)
//
//     @inlinable public init(_ value: repeat each T) {
//         self.value = (repeat each value)
//     }
//
//     public typealias Content = (repeat (each T).Content)
//
//     public func read(from url: URL) throws -> Content {
//         try (repeat (each value).read(from: url))
//     }
//
//     public func write(_ data: (repeat (each T).Content), to url: URL) throws {
//         try (repeat (each value).write((each data), to: url))
//     }
// }

public struct PairFileTreeComponent<F1: FileTreeComponent, F2: FileTreeComponent>: FileTreeComponent {
    public var value: (F1, F2)
    public typealias Content = (F1.Content, F2.Content)

    @inlinable public init(_ value: (F1, F2)) {
        self.value = value
    }

    public func read(from url: URL) throws -> Content {
        try (value.0.read(from: url), (value.1.read(from: url)))       
    } 

    public func write(_ data: (F1.Content, F2.Content), to url: URL) throws {
        try value.0.write(data.0, to: url)
        try value.1.write(data.1, to: url)
    }
}

