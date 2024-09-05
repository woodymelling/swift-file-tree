import Foundation
import Dependencies
import DependenciesMacros
import UniformTypeIdentifiers

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

    func read(from url: URL) throws -> FileType
}

struct TupleFileSystemComponent<each T: FileSystemComponent>: FileSystemComponent {
    public var value: (repeat each T)

    @inlinable public init(_ value: (repeat each T)) {
        self.value = value
    }

    typealias FileType = (repeat (each T).FileType)

    func read(from url: URL) throws -> FileType {
        try (repeat (each value).read(from: url))
    }
}

struct File: FileSystemComponent {
    let fileName: String
    let fileType: UTType

    init(_ fileName: String, _ fileType: UTType) {
        self.fileName = fileName
        self.fileType = fileType
    }

    func read(from url: URL) throws -> FileContent {
        @Dependency(FileManagerClient.self) var fileManagerClient
        let fileUrl = url.appendingPathComponent(fileName, conformingTo: fileType)


        return try FileContent(
            fileName: self.fileName,
            fileType: self.fileType,
            data: fileManagerClient.data(contentsOf: fileUrl)
        )
    }
}

struct Directory<Content: FileSystemComponent>: FileSystemComponent {
    let path: String

    var content: Content

    init(_ path: String, @FileSystemBuilder content: () -> Content) {
        self.path = path
        self.content = content()
    }

    func read(from url: URL) throws -> DirectoryContents<Content.FileType> {
        let directoryURL = url.appending(component: self.path)

        return try DirectoryContents(
            directoryName: self.path,
            components: content.read(from: directoryURL)
        )
    }
}

struct Many<Content: FileSystemComponent>: FileSystemComponent {
    var content: (String) -> Content

    init(@FileSystemBuilder _ content: @escaping (String) -> Content) {
        self.content = content
    }

    func read(from url: URL) throws -> [Content.FileType] {
        @Dependency(\.fileManagerClient) var fileManagerClient

        let paths = try fileManagerClient.contentsOfDirectory(atPath: url)

        let components = paths.map {
            content($0.deletingPathExtension().lastPathComponent)
        }

        return try components.map { try $0.read(from: url) }

    }
}

struct Optionally<Content: FileSystemComponent>: FileSystemComponent {
    var content: () -> Content

    init(@FileSystemBuilder content: @escaping () -> Content) {
        self.content = content
    }

    func read(from url: URL) throws -> Content.FileType? {
        nil
    }
}

// MARK: Contents
struct FileContent: Equatable {
    var fileName: String
    var fileType: UTType
    var data: Data
}

struct DirectoryContents<each T> {
    var directoryName: String
    var components: (repeat each T)

    init(directoryName: String, components: (repeat each T)) {
        self.directoryName = directoryName
        self.components = components
    }

}

extension DirectoryContents: Equatable where repeat each T: Equatable {
    static func == (lhs: Self, rhs: Self) -> Bool {
        guard lhs.directoryName == rhs.directoryName else { return false }
        for (left, right) in repeat (each lhs.components, each rhs.components) {
          guard left == right else { return false }
        }
        return true
      }


}


func foo() {


//
//    let dirFileOptionalFile: DirectoryContents<(FileContent, FileContent?)> = Directory("") {
//        File("")
//        Optionally {
//            File("")
//        }
//    }.read()
//
//    let dirFileDirFile: DirectoryContents<(FileContent, DirectoryContents<FileContent>)> = Directory("") {
//        File("")
//        Directory("") {
//            File("")
//        }
//    }.read()
//
//
//    let fullStructure: DirectoryContents<(FileContent, FileContent, DirectoryContents<[FileContent]>)> = Directory("") {
//        File("event-info.yaml")
//
//        File("contact-info.yaml")
//
//        Directory("schedules") {
//            Many {
//                File($0)
//            }
//        }
//    }.read()
}

@DependencyClient
struct FileManagerClient: Sendable {
    var data: @Sendable (_ contentsOf: URL) throws -> Data
    var contentsOfDirectory: @Sendable (_ atPath: URL) throws -> [URL]
}

extension FileManagerClient: TestDependencyKey {
    static let testValue: FileManagerClient = FileManagerClient()
}

extension DependencyValues {
    var fileManagerClient: FileManagerClient {
        get { self[FileManagerClient.self] }
        set { self[FileManagerClient.self] = newValue }
    }
}


extension UTType {
    static let markdown: UTType = UTType("md")!
}



