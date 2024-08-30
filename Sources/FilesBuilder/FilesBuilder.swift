// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation

@resultBuilder
struct FileSystemBuilder {
    public static func buildBlock<each Content>(_ content: repeat each Content) -> TupleFileSystemComponent<(repeat each Content)> where repeat each Content: FileSystemComponent {
        return TupleFileSystemComponent((repeat each content))
    }
}


struct TupleFileSystemComponent<T> : FileSystemComponent {
    public var value: T
    @inlinable public init(_ value: T) { self.value = value }
}

protocol FileSystemComponent { }

struct FileDescriptor {
    var fileName: String
    var data: Data
}

struct File: FileSystemComponent {
    let path: String

    init(_ path: String) {
        self.path = path
    }
}

struct Directory<Content: FileSystemComponent>: FileSystemComponent {
    let path: String

    init(_ path: String, @FileSystemBuilder content: () -> Content) {
        self.path = path
    }
}

struct Many: FileSystemComponent {
    var content: (String) -> FileSystemComponent

    init(@FileSystemBuilder _ content: @escaping (String) -> FileSystemComponent) {
        self.content = content
    }
}
