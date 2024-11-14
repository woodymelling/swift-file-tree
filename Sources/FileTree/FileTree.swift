import Foundation
import Dependencies
import DependenciesMacros
import UniformTypeIdentifiers

// MARK: Result Builder
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

// MARK: Protocol
public protocol FileTreeComponent<FileType>: Sendable {
    associatedtype FileType: Sendable

    associatedtype Body

    func read(from url: URL) async throws -> FileType

    func write(_ data: FileType, to url: URL) async throws

    @FileTreeBuilder
    var body: Body { get }
}


public protocol StaticFileTreeComponent: FileTreeComponent {
    var path: StaticString { get }
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

    public func write(_ data: FileType, to url: URL) async throws {
        try await body.write(data, to: url)
    }
}

import SwiftUI
//extension FileTreeComponent where ViewBody == Never {
//    public var view: ViewBody {
//        return fatalError("Body of \(Self.self) should never be called")
//    }
//}

public struct FileTree<Content: FileTreeComponent>: FileTreeComponent {

    public var content: Content
    public typealias FileType = Content.FileType

    public init(@FileTreeBuilder content: () -> Content) {
        self.content = content()
    }

    public func read(from url: URL) async throws -> Content.FileType {
        try await self.content.read(from: url)
    }

    public func write(_ data: Content.FileType, to url: URL) async throws {
        try await self.content.write(data, to: url)
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

    public func write(_ data: (repeat (each T).FileType), to url: URL) async throws {
        try await (repeat (each value).write((each data), to: url))
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

// MARK: - File
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

    public func write(_ data: Data, to url: URL) async throws {
        @Dependency(\.fileManagerClient) var fileManagerClient
        let fileUrl = url.appendingPathComponent(fileName.description, withType: fileType)

        return try fileManagerClient.writeData(data: data, to: fileUrl)
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

    public func write(_ fileContent: FileContent<Data>, to url: URL) async throws {
        @Dependency(\.fileManagerClient) var fileManagerClient
        let fileURL = url.appendingPathComponent(fileContent.fileName, withType: fileType)

        try fileManagerClient.writeData(data: fileContent.data, to: fileURL)

    }
}


// MARK: - Directory

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

    public func write(_ data: Content.FileType, to url: URL) async throws {
        @Dependency(\.fileManagerClient) var fileManagerClient
        let directoryPath = url.appending(component: path.description)

        if !fileManagerClient.fileExists(atPath: directoryPath) {
            try fileManagerClient.createDirectory(at: directoryPath, withIntermediateDirectories: false)
        }

        try await content.write(data, to: directoryPath)
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
        let compoents = try await content.read(from: directoryURL)

        return DirectoryContents(
            directoryName: self.path,
            components: compoents
        )
    }

    public func write(_ directoryContents: DirectoryContents<Content.FileType>, to url: URL) async throws {
        @Dependency(\.fileManagerClient) var fileManagerClient
        let directoryPath = url.appending(component: path.description)

        try fileManagerClient.createDirectory(at: directoryPath, withIntermediateDirectories: false)

        try await content.write(directoryContents.components, to: directoryPath)
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

    public func write(_ data: [Content.FileType], to url: URL) async throws {
        @Dependency(\.fileManagerClient) var fileManagerClient

        // Diff the current and the old, and if theres changes, write those changes to the file system
        // This is difficult because there's dynamic content involved here.
        // I think I may need to use some sort of system where I generate the data into a temp directory,
        // Diff the new contents with the old contents, and

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

