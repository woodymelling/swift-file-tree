//
//  Conversions.swift
//  swift-file-tree
//
//  Created by Woodrow Melling on 10/23/24.
//

@preconcurrency import Conversions
import Foundation

// MARK: Converted
public struct _ConvertedFileTreeComponent<Upstream: FileTreeComponent, Downstream: Conversion>: FileTreeComponent
where Downstream.Input == Upstream.Content, Downstream.Output:  Equatable {
    public let upstream: Upstream
    public let downstream: Downstream

    @inlinable
    public init(upstream: Upstream, downstream: Downstream) {
        self.upstream = upstream
        self.downstream = downstream
    }

    @inlinable
    @inline(__always)
    public func read(from url: URL) throws -> Downstream.Output {
        try self.downstream.apply(upstream.read(from: url))
    }

    @inlinable
    @inline(__always)
    public func write(_ data: Downstream.Output, to url: URL) throws {
        try self.upstream.write(downstream.unapply(data), to: url)
    }
}



extension FileTreeComponent {
    @inlinable
    public func convert<C>(_ conversion: C) -> _ConvertedFileTreeComponent<Self, C> {
        .init(upstream: self, downstream: conversion)
    }

    @inlinable
    @inline(__always)
    public func convert<C>(@ConversionBuilder build: () -> C) -> _ConvertedFileTreeComponent<Self, C> {
        self.convert(build())
    }
}

//// MARK: ManyFiles
//public struct _MappedFileTreeComponent<
//    Component: FileTreeComponent,
//    C: Conversion
//>: FileTreeComponent where Component.Content == [C.Input] {
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
//        try original.write(originalData, to: url)
//    }
//}



//
func foo() {

    let x = File.Many(withExtension: "txt")
        .convert(Conversions.Identity())
}

extension FileTreeComponent where Content: Collection {
    public func map<NewContent, C>(
        _ conversion: C
    ) -> _ConvertedFileTreeComponent<Self, Conversions.MapValues<C>>
    where C: Conversion<Self.Content.Element, NewContent> {
        _ConvertedFileTreeComponent(
            upstream: self,
            downstream: Conversions.MapValues(conversion)
        )
    }

    public func map<NewContent, C>(
        @ConversionBuilder build: () -> C
    ) -> _ConvertedFileTreeComponent<Self, C>
    where C: Conversion<Self.Content.Element, NewContent> {
        _ConvertedFileTreeComponent(
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
import SwiftUI

extension _ConvertedFileTreeComponent: FileTreeViewable where Upstream: FileTreeViewable {
    public func view(for value: Downstream.Output) -> some View {
        ConversionView(
            upstream: upstream,
            downStreamUnapply: downstream.unapply,
            value: value
        )
    }

    struct ConversionView: View {

        var upstream: Upstream
        var downStreamUnapply: (Downstream.Output) throws -> Upstream.Content
        var value: Downstream.Output

        var result: Result<Upstream.Content, Error> {
            Result {
                try downStreamUnapply(value)
            }
        }

        var body: some View {
            switch result {
            case .success(let success):
                upstream.view(for: success)
            case .failure(let failure):
                ContentErrorView(error: failure)
            }
        }
    }
}

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
