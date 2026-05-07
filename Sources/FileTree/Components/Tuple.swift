//
//  Tuple.swift
//  swift-file-tree
//
//  Created by Woodrow Melling on 12/5/24.
//

import Foundation

public struct TupleFileSystemComponent<each T: FileTreeReader>: FileTreeReader {
    public var value: (repeat each T)

    @inlinable public init(_ value: repeat each T) {
        self.value = (repeat each value)
    }

    public typealias Content = (repeat (each T).Content)

    public func read(from url: URL) throws -> FileTreeResult<Content> {
        let results = (repeat try (each value).read(from: url))
        var diagnostics = DiagnosticReport<FileTreeLocation>()
        repeat diagnostics.append(contentsOf: (each results).diagnostics)
        var graph = SourceGraph()
        repeat graph.append((each results).graph)

        do {
            return .value(try (repeat (each results).output.requiredValue), graph: graph, diagnostics: diagnostics)
        } catch {
            return .invalid(graph: graph, diagnostics: diagnostics)
        }
    }

    // public func write(_ data: Content, to url: URL) throws {
    //     fatalError()
    //     // try (repeat (each value).write((each data), to: url))
    // }
}
