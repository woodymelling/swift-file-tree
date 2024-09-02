// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation

@resultBuilder
struct FileSystemBuilder {
    public static func buildExpression<Content>(_ content: Content) -> Content where Content: FileSystemComponent {
        content
    }

    public static func buildBlock<Content>(_ content: Content) -> Content where Content: FileSystemComponent {
        content
    }

    public static func buildBlock<each Content>(_ content: repeat each Content) -> TupleFileSystemComponent<repeat each Content> where repeat each Content: FileSystemComponent {
        return TupleFileSystemComponent((repeat each content))
    }
}


protocol FileSystemComponent {
    associatedtype FileType

    func read() -> FileType
}


struct FileContent {
    var fileName: String
    var data: Data
}


struct DirectoryContents<T> {
    var directoryName: String
    var components: T
}


struct TupleFileSystemComponent<each T: FileSystemComponent>: FileSystemComponent {
    public var value: (repeat each T)

    @inlinable public init(_ value: (repeat each T)) {
        self.value = value
    }

    typealias FileType = (repeat (each T).FileType)

    func read() -> FileType {
        (repeat (each value).read())
    }
}


struct File: FileSystemComponent {
    let path: String


    init(_ path: String) {
        self.path = path
    }

    func read() -> FileContent {
        return .init(fileName: "", data: Data())
    }
}

struct Directory<Content: FileSystemComponent>: FileSystemComponent {
    let path: String

    var content: Content

    init(_ path: String, @FileSystemBuilder content: () -> Content) {
        self.path = path
        self.content = content()
    }

    func read() -> DirectoryContents<Content.FileType> {
        return .init(
            directoryName: "",
            components: content.read()
        )
    }
}

struct Many<Content: FileSystemComponent>: FileSystemComponent {
    var content: (String) -> Content

    init(@FileSystemBuilder _ content: @escaping (String) -> Content) {
        self.content = content
    }

    func read() -> [Content.FileType] {
        []
    }
}


func foo() {
    let file: FileContent = File("AFile.txt").read()
    let directoryWithFile: DirectoryContents<FileContent> = Directory("") { File("") }.read()
    let dirDirFile: DirectoryContents<DirectoryContents<FileContent>> = Directory("") { Directory("") { File("") }}.read()

    let manyFile: [FileContent] = Many { File($0) }.read()
    let dirManyFile: DirectoryContents<[FileContent]> = Directory("") { Many { File($0) } }.read()

    let dirFileFile: DirectoryContents<(FileContent, FileContent)> = Directory("") {
        File("")
        File("")
    }.read()

    let dirFileDirFile: DirectoryContents<(FileContent, DirectoryContents<FileContent>)> = Directory("") {
        File("")
        Directory("") {
            File("")
        }
    }.read()


    let fullStructure: DirectoryContents<(FileContent, FileContent, DirectoryContents<[FileContent]>)> = Directory("") {
        File("event-info.yaml")

        File("contact-info.yaml")

        Directory("schedules") {
            Many {
                File($0)
            }
        }
    }.read()
}

