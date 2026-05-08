//
//  Conversions.swift
//  swift-file-tree
//
//  Created by Woodrow Melling on 10/23/24.
//

import Foundation

// MARK: Converted
public struct _ConvertedFileTreeReader<Upstream: FileTreeReader, Downstream: Conversion>: FileTreeReader
where Downstream.Input == Upstream.Content, Downstream.Output: Sendable {
    public let upstream: Upstream
    public let downstream: Downstream

    @inlinable
    public init(upstream: Upstream, downstream: Downstream) {
        self.upstream = upstream
        self.downstream = downstream
    }

    @inlinable
    @inline(__always)
    public func read(from url: URL) throws -> FileTreeResult<Downstream.Output> {
        let upstreamResult = try upstream.read(from: url)

        switch upstreamResult.output {
        case let .value(value):
            let conversionResult = downstream.apply(value, in: upstreamResult.graph)
            var diagnostics = upstreamResult.diagnostics
            diagnostics.append(contentsOf: conversionResult.diagnostics)

            switch conversionResult.output {
            case let .value(output) where !diagnostics.hasErrors:
                return .value(output, graph: upstreamResult.graph, diagnostics: diagnostics)
            case .value, .invalid:
                return .invalid(graph: upstreamResult.graph, diagnostics: diagnostics)
            }

        case .invalid:
            return .invalid(graph: upstreamResult.graph, diagnostics: upstreamResult.diagnostics)
        }
    }

    // @inlinable
    // @inline(__always)
    // public func write(_ data: Downstream.Output, to url: URL) throws {
    //     try self.upstream.write(downstream.unapply(data), to: url)
    // }
}

extension _ConvertedFileTreeReader: FileTreeWriter where Upstream: FileTreeWriter {
    public func write(
        _ content: Downstream.Output,
        to url: URL
    ) throws -> FileTreeResult<Downstream.Output> {
        let conversionResult = downstream.unapply(content, in: .init())
        var diagnostics = conversionResult.diagnostics

        switch conversionResult.output {
        case let .value(upstreamContent) where !diagnostics.hasErrors:
            let upstreamResult = try upstream.write(upstreamContent, to: url)
            diagnostics.append(contentsOf: upstreamResult.diagnostics)

            switch upstreamResult.output {
            case .value where !diagnostics.hasErrors:
                return .value(content, graph: upstreamResult.graph, diagnostics: diagnostics)
            case .value, .invalid:
                return .invalid(graph: upstreamResult.graph, diagnostics: diagnostics)
            }

        case .value, .invalid:
            return .invalid(diagnostics: diagnostics)
        }
    }
}



extension FileTreeReader {
    @inlinable
    public func convert<C>(_ conversion: C) -> _ConvertedFileTreeReader<Self, C>
    where C.Input == Content, C.Output: Sendable {
        .init(upstream: self, downstream: conversion)
    }

    @inlinable
    @inline(__always)
    public func convert<C>(@ConversionBuilder build: () -> C) -> _ConvertedFileTreeReader<Self, C>
    where C.Input == Content, C.Output: Sendable {
        self.convert(build())
    }
}

//// MARK: ManyFiles
//public struct _MappedFileTreeReader<
//    Component: FileTreeReader,
//    C: Conversion
//>: FileTreeReader where Component.Content == [C.Input] {
//    public typealias Content = [C.Output]
//
//    let original: Component
//    let conversion: C
//    
//    
//    public func read(from url: URL) throws -> [C.Output] {
//        let originalContents = try original.read(from: url)
//        return try originalContents.map { fileContent in
//            try conversion.apply(fileContent)
//        }
//    }
//    
//    public func write(_ data: [C.Output], to url: URL) throws {
//        let originalData = try data.map { fileContent in
//            return try conversion.unapply(fileContent)
//        }
//        try original. write(originalData, to: url)
//    }
//}



extension FileTreeReader where Content: Collection {
    public func map<NewContent, C>(
        _ conversion: C
    ) -> _ConvertedFileTreeReader<Self, Conversions.MapValues<C>>
    where C: Conversion<Self.Content.Element, NewContent>, NewContent: Sendable {
        _ConvertedFileTreeReader(
            upstream: self,
            downstream: Conversions.MapValues(conversion)
        )
    }

    public func map<NewContent, C>(
        @ConversionBuilder build: () -> C
    ) -> _ConvertedFileTreeReader<Self, C>
    where C: Conversion<Self.Content.Element, NewContent>, NewContent: Sendable {
        _ConvertedFileTreeReader(
            upstream: self,
            downstream: build()
        )
    }
}

// MARK: FileContentConversion
public struct FileContentConversion<AppliedConversion: Conversion>: Conversion {
    public typealias Input = FileContent<AppliedConversion.Input>
    public typealias Output = FileContent<AppliedConversion.Output>

    var conversion: AppliedConversion

    public init(_ converson: AppliedConversion) {
        self.conversion = converson
    }

    public init(@ConversionBuilder build: () -> AppliedConversion) {
        self.conversion = build()
    }

    public func apply(_ input: FileContent<AppliedConversion.Input>) throws -> FileContent<AppliedConversion.Output> {
        try input.map { try self.conversion.apply($0) }
    }

    public func unapply(_ output: FileContent<AppliedConversion.Output>) throws -> FileContent<AppliedConversion.Input> {
        try output.map { try self.conversion.unapply($0) }
    }
}

extension FileContentConversion: Sendable where AppliedConversion: Sendable {}

// MARK: DirectoryContentConversion
public struct DirectoryContentConversion<AppliedConversion: Conversion>: Conversion {
    public typealias Input = DirectoryContent<AppliedConversion.Input>
    public typealias Output = DirectoryContent<AppliedConversion.Output>

    var conversion: AppliedConversion

    public init(_ conversion: AppliedConversion) {
        self.conversion = conversion
    }

    public init(@ConversionBuilder build: () -> AppliedConversion) {
        self.conversion = build()
    }

    public func apply(_ input: DirectoryContent<AppliedConversion.Input>) throws -> DirectoryContent<AppliedConversion.Output> {
        try input.map { try self.conversion.apply($0) }
    }

    public func unapply(_ output: DirectoryContent<AppliedConversion.Output>) throws -> DirectoryContent<AppliedConversion.Input> {
        try output.map { try self.conversion.unapply($0) }
    }
}

extension DirectoryContentConversion: Sendable where AppliedConversion: Sendable {}


// MARK: SwiftUI
#if canImport(SwiftUI)
import SwiftUI

// extension _ConvertedFileTreeReader: FileTreeViewable where Upstream: FileTreeViewable {
//     public func view(for value: Downstream.Output) -> some View {
//         ConversionView(
//             upstream: upstream,
//             downStreamUnapply: downstream.unapply,
//             value: value
//         )
//     }
//
//     struct ConversionView: View {
//
//         var upstream: Upstream
//         var downStreamUnapply: (Downstream.Output) throws -> Upstream.Content
//         var value: Downstream.Output
//
//         var result: Result<Upstream.Content, Error> {
//             Result {
//                 try downStreamUnapply(value)
//             }
//         }
//
//         var body: some View {
//             switch result {
//             case .success(let success):
//                 upstream.view(for: success)
//             case .failure(let failure):
//                 ContentErrorView(error: failure)
//             }
//         }
//     }
// }

struct ContentErrorView<E: Error>: View {
    let error: E

    var body: some View {
        Label {
            Text(error.localizedDescription)
        } icon: {
            Image(systemName: "exclamationmark.octagon.fill")
                .foregroundStyle(.red)
        }
    }
}
#endif
//
//extension _ManyFileMapConversion: FileTreeViewable where File.Many: FileTreeViewable {
//    @MainActor
//    public func view(for value: [NewContent]) -> some View {
//        ConversionView(
//            upstream: original,
//            downStreamUnapply: conversion.unapply,
//            value: value
//        )
//    }
//
//    struct ConversionView: View {
//        var upstream: File.Many
//        var downStreamUnapply: (NewContent) throws -> FileContent<Data>
//        var value: [NewContent]
//
//        var result: Result<[FileContent<Data>], Error> {
//            Result {
//                try value.map { try downStreamUnapply($0) }
//            }
//        }
//
//        var body: some View {
//            switch result {
//            case .success(let success):
//                upstream.view(for: success)
//            case .failure(let failure):
//                ContentErrorView(error: failure)
//            }
//        }
//    }
//}

//extension _ManyDirectoryMapConversion: FileTreeViewable where Component: FileTreeViewable, Directory<Component>.Many: FileTreeViewable {
//    @MainActor
//    public func view(for value: [NewContent]) -> some View {
//        ConversionView(
//            upstream: original,
//            downStreamUnapply: conversion.unapply,
//            value: value
//        )
//    }
//
//    struct ConversionView: View {
//        var upstream: Directory<Component>.Many
//        var downStreamUnapply: (NewContent) throws -> DirectoryContent<Component.Content>
//        var value: [NewContent]
//
//        var result: Result<[DirectoryContent<Component.Content>], Error> {
//            Result {
//                try value.map { try downStreamUnapply($0) }
//            }
//        }
//
//        var body: some View {
//            switch result {
//            case .success(let success):
//                upstream.view(for: success)
//            case .failure(let failure):
//                ContentErrorView(error: failure)
//            }
//        }
//    }
//}

extension Result where Self: Sendable {
    init(sendable operation: @Sendable () async throws(Failure) -> Success) async {
        do {
            self = try await .success(operation())
        } catch {
            self = .failure(error)
        }
    }
}
//public struct _ConvertedFileTreeReader<Upstream: FileTreeReader, Downstream: Conversion>: FileTreeReader
//where Downstream.Input == Upstream.Content, Downstream.Output:  Equatable {
//    public let upstream: Upstream
//    public let downstream: Downstream
//
//    @inlinable
//    public init(upstream: Upstream, downstream: Downstream) {
//        self.upstream = upstream
//        self.downstream = downstream
//    }
//
//    @inlinable
//    @inline(__always)
//    public func read(from url: URL) throws -> Downstream.Output {
//        try self.downstream.apply(upstream.read(from: url))
//    }
//
//    // @inlinable
//    // @inline(__always)
//    // public func write(_ data: Downstream.Output, to url: URL) throws {
//    //     try self.upstream.write(downstream.unapply(data), to: url)
//    // }
//}
public struct _OptionalConvertedFileTreeReader<Upstream: FileTreeReader, Downstream: Conversion>: FileTreeReader
where Upstream.Content == Downstream.Input?, Downstream.Output: Sendable {
    public let upstream: Upstream
    public let downstream: Downstream

    public init(upstream: Upstream, downstream: Downstream) {
        self.upstream = upstream
        self.downstream = downstream
    }

    public func read(from url: URL) throws -> FileTreeResult<Downstream.Output?> {
        let upstreamResult = try upstream.read(from: url)

        switch upstreamResult.output {
        case let .value(input):
            guard let input else {
                return .value(nil, graph: upstreamResult.graph, diagnostics: upstreamResult.diagnostics)
            }

            let conversionResult = downstream.apply(input, in: upstreamResult.graph)
            var diagnostics = upstreamResult.diagnostics
            diagnostics.append(contentsOf: conversionResult.diagnostics)

            switch conversionResult.output {
            case let .value(output) where !diagnostics.hasErrors:
                return .value(.some(output), graph: upstreamResult.graph, diagnostics: diagnostics)
            case .value, .invalid:
                return .invalid(graph: upstreamResult.graph, diagnostics: diagnostics)
            }

        case .invalid:
            return .invalid(graph: upstreamResult.graph, diagnostics: upstreamResult.diagnostics)
        }
    }

    public typealias Content = Downstream.Output?
}

extension File.Optional {
    public func convert<C>(_ conversion: C) -> _OptionalConvertedFileTreeReader<Self, C>
    where Content == C.Input?, C: Conversion, C.Output: Sendable {
        _OptionalConvertedFileTreeReader(upstream: self, downstream: conversion)
    }
}

public struct _DecodedFileTreeReader<Upstream: FileTreeReader, Codec: FileTreeCodec>: FileTreeReader
where Upstream.Content == Data {
    public typealias Content = LogicalSource<Codec.Value>

    public var upstream: Upstream
    public var kind: SourceGraph.Node.Logical.KindName
    public var codec: Codec
    public var key: @Sendable (Codec.Value) -> SourceGraph.Node.Logical.Key?

    public init(
        upstream: Upstream,
        kind: SourceGraph.Node.Logical.KindName,
        codec: Codec,
        key: @escaping @Sendable (Codec.Value) -> SourceGraph.Node.Logical.Key?
    ) {
        self.upstream = upstream
        self.kind = kind
        self.codec = codec
        self.key = key
    }

    public func read(from url: URL) throws -> FileTreeResult<Content> {
        let upstreamResult = try upstream.read(from: url)

        switch upstreamResult.output {
        case let .value(data):
            do {
                let value = try codec.decode(data)
                var graph = upstreamResult.graph
                let logicalID = graph.insertLogicalSource(
                    kind: kind,
                    key: key(value),
                    parsedFrom: graph.root
                )
                return .value(
                    LogicalSource(value: value, handle: .init(nodeID: logicalID)),
                    graph: graph,
                    diagnostics: upstreamResult.diagnostics
                )
            } catch {
                var diagnostics = upstreamResult.diagnostics
                diagnostics.append(
                    Diagnostic<FileTreeLocation>(
                        severity: .error,
                        code: "file-tree.decode.failed",
                        message: String(describing: error),
                        location: .init(sourceLocation: upstreamResult.graph.root.flatMap {
                            upstreamResult.graph.location(for: .init(nodeID: $0))
                        })
                    )
                )
                return .invalid(graph: upstreamResult.graph, diagnostics: diagnostics)
            }

        case .invalid:
            return .invalid(graph: upstreamResult.graph, diagnostics: upstreamResult.diagnostics)
        }
    }
}

extension FileTreeReader where Content == Data {
    public func decode<Value, Codec>(
        _ type: Value.Type,
        as kind: SourceGraph.Node.Logical.KindName,
        using codec: Codec
    ) -> _DecodedFileTreeReader<Self, Codec>
    where Value: Identifiable & Sendable, Value.ID: CustomStringConvertible, Codec: FileTreeCodec, Codec.Value == Value {
        _DecodedFileTreeReader(
            upstream: self,
            kind: kind,
            codec: codec,
            key: { SourceGraph.Node.Logical.Key(rawValue: $0.id.description) }
        )
    }

    public func decode<Value, Codec>(
        _ type: Value.Type,
        as kind: SourceGraph.Node.Logical.KindName,
        key: @escaping @Sendable (Value) -> SourceGraph.Node.Logical.Key?,
        using codec: Codec
    ) -> _DecodedFileTreeReader<Self, Codec>
    where Value: Sendable, Codec: FileTreeCodec, Codec.Value == Value {
        _DecodedFileTreeReader(upstream: self, kind: kind, codec: codec, key: key)
    }
}
