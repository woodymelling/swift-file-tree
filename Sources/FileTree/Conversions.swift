//
//  Conversions.swift
//  swift-file-tree
//
//  Created by Woodrow Melling on 10/23/24.
//

import Conversions
import Foundation

// MARK: Converted
public struct _ConvertedFileTreeComponent<Upstream: FileTreeComponent, Downstream: Conversion & Sendable>: FileTreeComponent
where Downstream.Input == Upstream.Content, Downstream.Output: Sendable & Equatable {
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
    public func convert<NewOutput, C: Conversion<C.Output, NewOutput>>(@ConversionBuilder<C.Output, NewOutput> build: () -> C) -> _ConvertedFileTreeComponent<Self, C> {
        self.convert(build())
    }
}

// MARK: ManyFiles
public struct _ManyFileMapConversion<NewContent: Sendable, C: Conversion<FileContent<Data>, NewContent>>: FileTreeComponent {
    public typealias Content = [NewContent]

    let original: File.Many
    let conversion: C


    public func read(from url: URL) throws -> [NewContent] {
        let originalContents = try original.read(from: url)
        return try originalContents.map { fileContent in
            return try conversion.apply(fileContent)
        }
    }

    public func write(_ data: [NewContent], to url: URL) throws {
        let originalData = try data.map { fileContent in
            return try conversion.unapply(fileContent)
        }
        try original.write(originalData, to: url)
    }
}

extension File.Many {
    public func map<NewContent: Sendable, C: Conversion<FileContent<Data>, NewContent>>(
        _ conversion: C
    ) -> _ManyFileMapConversion<NewContent, C> {
        return _ManyFileMapConversion(
            original: self,
            conversion: conversion
        )
    }

    public func map<NewContent: Sendable, C: Conversion<FileContent<Data>, NewContent>>(
        @ConversionBuilder<FileContent<Data>, NewContent> build: () -> C
    ) -> _ManyFileMapConversion<NewContent, C> {
        return _ManyFileMapConversion(
            original: self,
            conversion: build()
        )
    }
}


// MARK: ManyDirectories
public struct _ManyDirectoryMapConversion<Component: FileTreeComponent, NewContent: Sendable, C: Conversion<DirectoryContent<Component.Content>, NewContent>>: FileTreeComponent {
    public typealias Content = [NewContent]

    let original: Directory<Component>.Many
    let conversion: C

    public init(original: Directory<Component>.Many, conversion: C) {
        self.original = original
        self.conversion = conversion
    }

    public func read(from url: URL) throws -> [NewContent] {
        let originalContents = try original.read(from: url)
        return try originalContents.map { dirContent in
            try conversion.apply(dirContent)
        }
    }

    public func write(_ data: [NewContent], to url: URL) throws {
        let originalData = try data.map { newContent in
            try conversion.unapply(newContent)
        }
        try original.write(originalData, to: url)
    }
}

extension Directory.Many {
    @inlinable
    @inline(__always)
    public func map<NewContent: Sendable, C: Conversion<DirectoryContent<Component.Content>, NewContent>>(
        _ conversion: C
    ) -> _ManyDirectoryMapConversion<Component, NewContent, C> {
        return _ManyDirectoryMapConversion(
            original: self,
            conversion: conversion
        )
    }

    @inlinable
    @inline(__always)
    public func map<NewContent: Sendable, C: Conversion<DirectoryContent<Component.Content>, NewContent>>(
        @ConversionBuilder<Component.Content, NewContent> build: () -> C
    ) -> _ManyDirectoryMapConversion<Component, NewContent, C> {
        return _ManyDirectoryMapConversion(
            original: self,
            conversion: build()
        )
    }
}


// MARK: FileContentConversion
public struct FileContentConversion<I, O, AppliedConversion: Conversion<I, O>>: Conversion {
    public typealias Input = FileContent<I>
    public typealias Output = FileContent<O>

    var conversion: AppliedConversion

    public init(_ converson: AppliedConversion) {
        self.conversion = converson
    }

    public init(@ConversionBuilder<I, O> build: () -> AppliedConversion) {
        self.conversion = build()
    }

    public func apply(_ input: FileContent<I>) throws -> FileContent<O> {
        try input.map { try self.conversion.apply($0) }
    }

    public func unapply(_ output: FileContent<O>) throws -> FileContent<I> {
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

    // THIS MANY NOT BE CORRECT, CIRCULAR REFERENCE?
    public init(@ConversionBuilder<AppliedConversion.Input, AppliedConversion.Output> build: () -> AppliedConversion) {
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
        var downStreamUnapply: @Sendable (Downstream.Output) throws -> Upstream.Content
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

extension _ManyFileMapConversion: FileTreeViewable where File.Many: FileTreeViewable {
    @MainActor
    public func view(for value: [NewContent]) -> some View {
        ConversionView(
            upstream: original,
            downStreamUnapply: conversion.unapply,
            value: value
        )
    }

    struct ConversionView: View {
        var upstream: File.Many
        var downStreamUnapply: @Sendable (NewContent) throws -> FileContent<Data>
        var value: [NewContent]

        var result: Result<[FileContent<Data>], Error> {
            Result {
                try value.map { try downStreamUnapply($0) }
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

extension _ManyDirectoryMapConversion: FileTreeViewable where Component: FileTreeViewable, Directory<Component>.Many: FileTreeViewable {
    @MainActor
    public func view(for value: [NewContent]) -> some View {
        ConversionView(
            upstream: original,
            downStreamUnapply: conversion.unapply,
            value: value
        )
    }

    struct ConversionView: View {
        var upstream: Directory<Component>.Many
        var downStreamUnapply: @Sendable (NewContent) throws -> DirectoryContent<Component.Content>
        var value: [NewContent]

        var result: Result<[DirectoryContent<Component.Content>], Error> {
            Result {
                try value.map { try downStreamUnapply($0) }
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

extension Result where Self: Sendable {
    init(sendable operation: @Sendable () async throws(Failure) -> Success) async {
        do {
            self = try await .success(operation())
        } catch {
            self = .failure(error)
        }
    }
}
