import Foundation
import Dependencies
import DependenciesMacros
import UniformTypeIdentifiers

@resultBuilder
public struct FileTreeBuilder {
    public static func buildExpression<Content>(_ content: Content) -> Content where Content: FileSystemComponent {
        content
    }

    public static func buildBlock<Content>(_ content: Content) -> Content where Content: FileSystemComponent {
        content
    }

    public static func buildBlock<each Content>(_ content: repeat each Content) -> TupleFileSystemComponent<repeat each Content> where repeat each Content: FileSystemComponent {
        return TupleFileSystemComponent(repeat each content)
    }
}

public protocol FileSystemComponent: Sendable {
    associatedtype FileType: Sendable

    func read(from url: URL) async throws -> FileType
}

public struct TupleFileSystemComponent<each T: FileSystemComponent>: FileSystemComponent {
    public var value: (repeat each T)

    @inlinable public init(_ value: repeat each T) {
        self.value = (repeat each value)
    }

    public typealias FileType = (repeat (each T).FileType)

    public func read(from url: URL) async throws -> FileType {
        try await (repeat (each value).read(from: url))
    }
}

public struct File: FileSystemComponent {
    let fileName: String
    let fileType: UTType

    public init(_ fileName: String, _ fileType: UTType) {
        self.fileName = fileName
        self.fileType = fileType
    }

    public func read(from url: URL) async throws -> FileContent {
        @Dependency(\.fileManagerClient) var fileManagerClient
        let fileUrl = url.appendingPathComponent(fileName, conformingTo: fileType)

        return try await FileContent(
            fileName: self.fileName,
            fileType: self.fileType,
            data: fileManagerClient.data(contentsOf: fileUrl)
        )
    }
}

public struct OptionalFile: FileSystemComponent {
    let fileName: String
    let fileType: UTType

    public init(_ fileName: String, _ fileType: UTType) {
        self.fileName = fileName
        self.fileType = fileType
    }

    public func read(from url: URL) async throws -> FileContent? {
        @Dependency(\.fileManagerClient) var fileManagerClient
        let fileURL = url.appendingPathComponent(fileName, conformingTo: fileType)

        guard fileManagerClient.fileExists(atPath: fileURL, isDirectory: true)
        else { return nil }


        return try await FileContent(
            fileName: self.fileName,
            fileType: self.fileType,
            data: fileManagerClient.data(contentsOf: fileURL)
        )
    }
}


public struct Directory<Content: FileSystemComponent>: FileSystemComponent {
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

public struct OptionalDirectory<Content: FileSystemComponent>: FileSystemComponent {
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
        guard fileManagerClient.fileExists(atPath: directoryURL, isDirectory: true)
        else { return nil }

        return try await DirectoryContents(
            directoryName: self.path,
            components: content.read(from: directoryURL)
        )
    }
}

public struct Many<Content: FileSystemComponent>: FileSystemComponent {
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
public struct FileContent: Hashable, Sendable {
    public var fileName: String
    public var fileType: UTType
    public var data: Data

    public init(fileName: String, fileType: UTType, data: Data) {
        self.fileName = fileName
        self.fileType = fileType
        self.data = data
    }
}

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



