import Foundation
import Dependencies
import DependenciesMacros
import UniformTypeIdentifiers

@resultBuilder
public struct FileTreeBuilder {
    public static func buildExpression<Content>(_ content: Content) -> Content where Content: FileTreeComponent {
        content
    }

    public static func buildBlock<Content>(_ content: Content) -> Content where Content: FileTreeComponent {
        content
    }

    public static func buildBlock<each Content>(_ content: repeat each Content) -> TupleFileSystemComponent<repeat each Content> where repeat each Content: FileTreeComponent {
        return TupleFileSystemComponent(repeat each content)
    }
}

public protocol FileTreeComponent<FileType>: Sendable {
    associatedtype FileType: Sendable

    associatedtype Body

    func read(from url: URL) async throws -> FileType

    @FileTreeBuilder
    var body: Body { get }
}

extension FileTreeComponent where Body == Never {
    public var body: Body {
        return fatalError("Body of \(Self.self) should never be called")
    }
}

extension FileTreeComponent where Body: FileTreeComponent, Body.FileType == FileType {
    public func read(from url: URL) async throws -> FileType {
        try await body.read(from: url)
    }
}

public struct FileTree<Content: FileTreeComponent>: FileTreeComponent {

    public var content: Content
    public typealias FileType = Content.FileType

    public init(@FileTreeBuilder content: () -> Content) {
        self.content = content()
    }

    public func read(from url: URL) async throws -> Content.FileType {
        try await self.content.read(from: url)
    }
}


public struct TupleFileSystemComponent<each T: FileTreeComponent>: FileTreeComponent {
    public var value: (repeat each T)

    @inlinable public init(_ value: repeat each T) {
        self.value = (repeat each value)
    }

    public typealias FileType = (repeat (each T).FileType)

    public func read(from url: URL) async throws -> FileType {
        try await (repeat (each value).read(from: url))
    }
}

public struct Errors: Error, Equatable, Sequence {

    var errors: [Error]

    typealias Index = Error
    public typealias Iterator = [Error].Iterator
    public func makeIterator() -> Array<any Error>.Iterator {
        errors.makeIterator()
    }

    public init?(_ errors: [Error]) {
        guard !errors.isEmpty
        else { return nil }

        self.errors = errors
    }

    public init?(_ sequence: Error...) {
        guard !sequence.isEmpty
        else { return nil }

        self.errors = sequence
    }


    public static func == (lhs: Self, rhs: Self) -> Bool {
        guard lhs.errors.count == rhs.errors.count else {
            return false
        }

        for (leftError, rightError) in zip(lhs.errors, rhs.errors) {
            if let leftEquatableError = leftError as? any Equatable,
               let rightEquatableError = rightError as? any Equatable {
                // If they are both equatable but not equal, return false
                if !leftEquatableError.isEqual(to: rightEquatableError) {
                    return false
                }
            }
        }

        return true
    }

    


}

private extension Equatable {
    // Helper to safely compare any two Equatable instances
    func isEqual(to other: any Equatable) -> Bool {
        self == (other as? Self)
    }
}

extension Conversion {
    static var id: Conversions.Identity<Input> {
        Conversions.Identity<Input>()
    }
}

public enum FileType: Sendable, Hashable {
    case utType(UTType)
    case `extension`(FileExtension)
}

public struct FileExtension: ExpressibleByStringLiteral, Sendable, Hashable {
    var rawValue: String

    public init(stringLiteral value: StringLiteralType) {
        self.rawValue = value
    }
}

extension URL {
    func appendingPathComponent(_ partialName: String, withType type: FileType) -> URL {
        switch type {
        case .utType(let utType):
            self.appendingPathComponent(partialName, conformingTo: utType)
        case .extension(let string):
            self.appending(path: partialName).appendingPathExtension(string.rawValue)
        }
    }
}


public struct StaticFile: FileTreeComponent {
    let fileName: StaticString
    let fileType: FileType

    public init(_ fileName: StaticString, _ fileType: UTType) {
        self.fileName = fileName
        self.fileType = .utType(fileType)
    }

    public init(_ fileName: StaticString, _ fileType: FileExtension) {
        self.fileName = fileName
        self.fileType = .extension(fileType)
    }

    public func read(from url: URL) async throws -> Data {
        @Dependency(\.fileManagerClient) var fileManagerClient
        let fileUrl = url.appendingPathComponent(fileName.description, withType: fileType)

        return try await fileManagerClient.data(contentsOf: fileUrl)
    }
}

public struct File: FileTreeComponent {
    let fileName: String
    let fileType: FileType

    public init(_ fileName: String, _ fileType: UTType) {
        self.fileName = fileName
        self.fileType = .utType(fileType)
    }

    public init(_ fileName: String, _ fileType: FileExtension) {
        self.fileName = fileName
        self.fileType = .extension(fileType)
    }

    public func read(from url: URL) async throws -> FileContent<Data> {
        @Dependency(\.fileManagerClient) var fileManagerClient
        let fileUrl = url.appendingPathComponent(fileName, withType: fileType)

        return try await FileContent(
            fileName: self.fileName,
            data: fileManagerClient.data(contentsOf: fileUrl)
        )
    }
}

public struct OptionalFile: FileTreeComponent {
    let fileName: String
    let fileType: FileType

    public init(_ fileName: String, _ fileType: FileType) {
        self.fileName = fileName
        self.fileType = fileType
    }

    public init(_ fileName: String, _ fileType: FileExtension) {
        self.fileName = fileName
        self.fileType = .extension(fileType)
    }

    public func read(from url: URL) async throws -> FileContent<Data>? {
        @Dependency(\.fileManagerClient) var fileManagerClient
        let fileURL = url.appendingPathComponent(fileName, withType: fileType)

        guard fileManagerClient.fileExists(atPath: fileURL)
        else { return nil }


        return try await FileContent(
            fileName: self.fileName,
            data: fileManagerClient.data(contentsOf: fileURL)
        )
    }
}


public struct Directory<Content: FileTreeComponent>: FileTreeComponent {
    let path: String

    var content: Content

    public init(_ path: String, @FileTreeBuilder content: () -> Content) {
        self.path = path
        self.content = content()
    }

    // This doesn't work because when Content.FileType is a tuple, we want DirectoryContents to have multiple types from that parameter pack
    public func read(from url: URL) async throws -> DirectoryContents<Content.FileType> {
        let directoryURL = url.appending(component: self.path)
        let x = try await content.read(from: directoryURL)

        return DirectoryContents(
            directoryName: self.path,
            components: x
        )
    }
}

public struct StaticDirectory<Content: FileTreeComponent>: FileTreeComponent {
    let path: StaticString
    var content: Content

    public init(_ path: StaticString, @FileTreeBuilder content: () -> Content) {
        self.path = path
        self.content = content()
    }

    public func read(from url: URL) async throws -> Content.FileType {
        let directoryURL = url.appending(component: self.path.description)

        return try await content.read(from: directoryURL)
    }
}

public struct OptionalDirectory<Content: FileTreeComponent>: FileTreeComponent {
    let path: String

    var content: Content

    public init(_ path: String, @FileTreeBuilder content: () -> Content) {
        self.path = path
        self.content = content()
    }

    // This doesn't work because when Content.FileType is a tuple, we want DirectoryContents to have multiple types from that parameter pack
    public func read(from url: URL) async throws -> DirectoryContents<Content.FileType>? {
        @Dependency(\.fileManagerClient) var fileManagerClient

        let directoryURL = url.appending(component: self.path)
        guard fileManagerClient.fileExists(atPath: directoryURL)
        else { return nil }

        return try await DirectoryContents(
            directoryName: self.path,
            components: content.read(from: directoryURL)
        )
    }
}

public struct Many<Content: FileTreeComponent>: FileTreeComponent {
    var content: @Sendable (String) -> Content

    public init(@FileTreeBuilder _ content: @Sendable @escaping (String) -> Content) {
        self.content = content
    }

    public func read(from url: URL) async throws -> [Content.FileType] {
        @Dependency(\.fileManagerClient) var fileManagerClient

        let paths = try fileManagerClient.contentsOfDirectory(atPath: url)

        let components = paths.map {
            content($0.deletingPathExtension().lastPathComponent)
        }

        return try await withThrowingTaskGroup(of: Content.FileType.self) {
            for component in components {
                $0.addTask {
                    try await component.read(from: url)
                }
            }

            var results: [Content.FileType] = []

            for try await result in $0 {
                results.append(result)
            }

            return results
        }
    }
}

// - MARK: Contents
public struct FileContent<Content> {
    public var fileName: String
    public var data: Content

    public init(fileName: String, data: Content) {
        self.fileName = fileName
        self.data = data
    }
}

public extension FileContent {
    func map<NewContent>(_ transform: (Content) throws -> NewContent) rethrows -> FileContent<NewContent> {
        try FileContent<NewContent>(
            fileName: fileName,
            data: transform(self.data)
        )
    }
}

extension FileContent: Hashable where Content: Hashable {}
extension FileContent: Sendable where Content: Sendable {}
extension FileContent: Equatable where Content: Equatable {}

public struct DirectoryContents<T: Sendable>: Sendable {
    public var directoryName: String
    public var components: T

    public init(directoryName: String, components: T) {
        self.directoryName = directoryName
        self.components = components
    }
}

extension DirectoryContents: Equatable where T: Equatable {}
extension DirectoryContents: Hashable where T: Hashable {}

import Parsing

public struct Map<Upstream: FileTreeComponent, NewOutput: Sendable>: FileTreeComponent {
    public let upstream: Upstream
    public let transform: @Sendable (Upstream.FileType) throws -> NewOutput

    public func read(from url: URL) async throws -> NewOutput {
        try await self.transform(upstream.read(from: url))
    }
}

import Parsing

public struct MapConversionComponent<Upstream: FileTreeComponent, Downstream: AsyncConversion & Sendable>: FileTreeComponent
where Downstream.Input == Upstream.FileType, Downstream.Output: Sendable {
    public let upstream: Upstream
    public let downstream: Downstream

    @inlinable
    public init(upstream: Upstream, downstream: Downstream) {
        self.upstream = upstream
        self.downstream = downstream
    }

    @inlinable
    @inline(__always)
    public func read(from url: URL) async throws -> Downstream.Output {
        try await self.downstream.apply(upstream.read(from: url))
    }
//
//    @inlinable
//    public func print(_ output: Downstream.Output, into input: inout Upstream.Input) rethrows {
//        try self.upstream.print(self.downstream.unapply(output), into: &input)
//    }
}

extension FileTreeComponent {
    public func map<NewOutput>(
        _ transform: @escaping @Sendable (FileType) throws -> NewOutput
    ) -> Map<Self, NewOutput> {
        .init(upstream: self, transform: transform)
    }

    @inlinable
    public func map<C>(_ conversion: C) -> MapConversionComponent<Self, C> {
        .init(upstream: self, downstream: conversion)
    }

    /*
     StaticFile("blah", "yaml")
        .map {
            DataToString<Data, String>()
         }
     */

    public func map<C>(@ConversionBuilder build: () -> C) -> MapConversionComponent<Self, C> {
        self.map(build())
    }
}

