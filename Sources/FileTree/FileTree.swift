import Foundation
import Dependencies
import DependenciesMacros
import UniformTypeIdentifiers

// MARK: Result Builder
@resultBuilder
public struct FileTreeBuilder {
    public static func buildExpression<Component>(_ content: Component) -> Component where Component: FileTreeComponent {
        content
    }

    public static func buildBlock<Component>(_ content: Component) -> Component where Component: FileTreeComponent {
        content
    }

    public static func buildBlock<each Component>(_ content: repeat each Component) -> TupleFileSystemComponent<repeat each Component> where repeat each Component: FileTreeComponent {
        return TupleFileSystemComponent(repeat each content)
    }
}

// MARK: Protocol
public protocol FileTreeComponent<FileType>: Sendable {
    associatedtype FileType: Sendable

    associatedtype Body

    func read(from url: URL) throws -> FileType

    func write(_ data: FileType, to url: URL) throws

    @FileTreeBuilder
    var body: Body { get }
}

public protocol FileTreeViewable: FileTreeComponent {
    associatedtype ViewBody: View

    @ViewBuilder
    @MainActor
    func view(for fileType: FileType) -> ViewBody
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
    public func read(from url: URL) throws -> FileType {
        try body.read(from: url)
    }

    public func write(_ data: FileType, to url: URL) throws {
        try body.write(data, to: url)
    }

}


import SwiftUI

public struct FileTree<Component: FileTreeComponent>: FileTreeComponent {

    public var content: Component
    public typealias FileType = Component.FileType

    public init(@FileTreeBuilder content: () -> Component) {
        self.content = content()
    }

    public func read(from url: URL) throws -> Component.FileType {
        try self.content.read(from: url)
    }

    public func write(_ data: Component.FileType, to url: URL) throws {
        try self.content.write(data, to: url)
    }
}

public struct TupleFileSystemComponent<each T: FileTreeComponent>: FileTreeComponent {
    public var value: (repeat each T)

    @inlinable public init(_ value: repeat each T) {
        self.value = (repeat each value)
    }

    public typealias FileType = (repeat (each T).FileType)

    public func read(from url: URL) throws -> FileType {
        try (repeat (each value).read(from: url))
    }

    public func write(_ data: (repeat (each T).FileType), to url: URL) throws {
        try (repeat (each value).write((each data), to: url))
    }
}

enum UTFileExtension: Sendable, Hashable {
    case utType(UTType)
    case `extension`(FileExtension)

    var identifier: String {
        switch self {
        case .utType(let utType):
            utType.identifier
        case .extension(let e):
            e.rawValue
        }
    }
}

public struct FileExtension: ExpressibleByStringLiteral, Sendable, Hashable {
    var rawValue: String

    public init(stringLiteral value: StringLiteralType) {
        self.rawValue = value
    }
}

extension URL {
    func appendingPathComponent(_ partialName: String, withType type: UTFileExtension) -> URL {
        switch type {
        case .utType(let utType):
            self.appendingPathComponent(partialName, conformingTo: utType)
        case .extension(let string):
            self.appending(path: partialName).appendingPathExtension(string.rawValue)
        }
    }
}


// MARK: - File
public struct File: FileTreeComponent {
    let fileName: StaticString
    let fileType: UTFileExtension

    public init(_ fileName: StaticString, _ fileType: UTType) {
        self.fileName = fileName
        self.fileType = .utType(fileType)
    }

    public init(_ fileName: StaticString, _ fileType: FileExtension) {
        self.fileName = fileName
        self.fileType = .extension(fileType)
    }

    public func read(from url: URL) throws -> Data {
        @Dependency(\.fileManagerClient) var fileManagerClient
        let fileUrl = url.appendingPathComponent(fileName.description, withType: fileType)

        return try fileManagerClient.data(contentsOf: fileUrl)
    }

    public func write(_ data: Data, to url: URL) throws {
        @Dependency(\.fileManagerClient) var fileManagerClient
        let fileUrl = url.appendingPathComponent(fileName.description, withType: fileType)

        return try fileManagerClient.writeData(data: data, to: fileUrl)
    }
}

extension File {
    public struct Many: FileTreeComponent {
        public typealias FileType = [FileContent<Data>]
        let fileType: UTFileExtension

        public init(withExtension fileType: UTType) {
            self.fileType = .utType(fileType)
        }

        public init(withExtension fileType: FileExtension) {
            self.fileType = .extension(fileType)
        }
        public func read(from url: URL) throws -> [FileContent<Data>] {


            @Dependency(\.fileManagerClient) var fileManagerClient

            let paths = try fileManagerClient.contentsOfDirectory(atPath: url)
            let filteredPaths = paths.filter { $0.pathExtension == self.fileType.identifier }

            return try filteredPaths.map { fileURL in

                let data = try fileManagerClient.data(contentsOf: fileURL)
                return FileContent(fileName: fileURL.deletingPathExtension().lastPathComponent, data: data)
            }.sorted { $0.fileName < $1.fileName }
        }

        public func write(_ data: [FileContent<Data>], to url: URL) throws {
            guard writingToEmptyDirectory
            else {
                reportIssue("""
            Writing an array of files to a directory that may already have contents currently unsupported.
            
            This is because of the circumstance where a file exists in the directory, but not in the array
            It is difficult to determine if the file should be deleted, or if it exists outside of the purview of the `Files` block and should be left alone.
            
            The semantics of Many may need to be tweaked to make this determination more clear.
            
            To allow writing to the directory, use:
            
            ```
            $writingToEmptyDirectory.withValue(true) { 
                Files(withExtension: .text).write([Data(), Data(), Data()]))
            }
            ```
            
            which will naively write all the contents to the directory, and not delete anything that is already there.
            """)
                return
            }

            @Dependency(\.fileManagerClient) var fileManagerClient

            for fileContent in data {
                let fileURL = url.appendingPathComponent(fileContent.fileName, withType: self.fileType)
                try fileManagerClient.writeData(data: fileContent.data, to: fileURL)
            }
        }
    }
}

// MARK: - Directory

public struct Directory<Component: FileTreeComponent>: FileTreeComponent {
    let path: StaticString
    var content: Component

    public init(_ path: StaticString, @FileTreeBuilder content: () -> Component) {
        self.path = path
        self.content = content()
    }

    public func read(from url: URL) throws -> Component.FileType {
        let directoryURL = url.appending(component: self.path.description)

        return try content.read(from: directoryURL)
    }

    public func write(_ data: Component.FileType, to url: URL) throws {
        @Dependency(\.fileManagerClient) var fileManagerClient
        let directoryPath = url.appending(component: path.description)

        if !fileManagerClient.fileExists(atPath: directoryPath) {
            try fileManagerClient.createDirectory(at: directoryPath, withIntermediateDirectories: false)
        }

        try content.write(data, to: directoryPath)
    }
}

extension Directory {
    public struct Many: FileTreeComponent {
        public typealias FileType = [DirectoryContents<Component.FileType>]

        var component: Component

        public init(@FileTreeBuilder content: @Sendable () -> Component) {
            self.component = content()
        }

        public func read(from url: URL) throws -> [DirectoryContents<Component.FileType>] {
            @Dependency(\.fileManagerClient) var fileManagerClient

            let directoryNames = try fileManagerClient.directories(atPath: url)

            return try directoryNames.map {
                let contents = try component.read(from: $0)
                return DirectoryContents(directoryName: $0.lastPathComponent, components: contents)
            }.sorted(by: { $0.directoryName < $1.directoryName })
        }

        public func write(_ data: [DirectoryContents<Component.FileType>], to url: URL) throws {
            guard writingToEmptyDirectory
            else {
                reportIssue("""
                Writing a `Many` to a directory that may already have contents currently unsupported.
                
                This is because it is difficult to determine if a value that does not exist in the array of values getting written should be deleted because it was removed,
                or if it exists outside of the purview of the `Many { }` block and should be left alone.
                
                The semantics of Many may need to be tweaked to make this determination more clear.
                
                To allow writing to the directory, use:
                
                ```
                $writingToEmptyDirectory.withValue(true) { 
                    Directories { StaticFile($0, "txt") }.write(...)
                }
                ```
                
                which will naively write all the contents to the directory, and not delete anything that is already there.
                """)
                return
            }


            @Dependency(\.fileManagerClient) var fileManagerClient

            if !fileManagerClient.fileExists(atPath: url) {
                try fileManagerClient.createDirectory(at: url, withIntermediateDirectories: true)
            }

            for directoryContent in data {
                let directoryURL = url.appendingPathComponent(directoryContent.directoryName)

                if !fileManagerClient.fileExists(atPath: directoryURL) {
                    try fileManagerClient.createDirectory(at: directoryURL, withIntermediateDirectories: false)
                }

                try component.write(directoryContent.components, to: directoryURL)
            }
        }
    }

}

@TaskLocal
var writingToEmptyDirectory = false


// - MARK: Contents
public struct FileContent<Component> {
    public var fileName: String
    public var data: Component

    public init(fileName: String, data: Component) {
        self.fileName = fileName
        self.data = data
    }
}

extension FileContent: Hashable where Component: Hashable {}
extension FileContent: Sendable where Component: Sendable {}
extension FileContent: Equatable where Component: Equatable {}
public extension FileContent {
    func map<NewContent>(_ transform: (Component) throws -> NewContent) rethrows -> FileContent<NewContent> {
        try FileContent<NewContent>(
            fileName: fileName,
            data: transform(self.data)
        )
    }
}


// MARK: DirectoryContents
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

// MARK: FileTree + SwiftUI
extension File: FileTreeViewable {
    public func view(for fileType: Data) -> some View {
        return AnyView(
            FileView(
                fileName: self.fileName.description,
                fileType: self.fileType,
                searchItems: [fileName.description]
            )
        )
    }
}

extension File.Many: FileTreeViewable {
    public func view(for files: [FileContent<Data>]) -> some View {
        ForEach(files, id: \.fileName) {
            FileView(
                fileName: $0.fileName,
                fileType: self.fileType,
                searchItems: [$0.fileName]
            )
        }
    }
}

extension Directory.Many: FileTreeViewable where Component: FileTreeViewable {
    public func view(for directories: [DirectoryContents<Component.FileType>]) -> some View {
        ForEach(directories, id: \.directoryName) {
            DirectoryView(
                name: $0.directoryName,
                data: $0.components,
                content: self.component,
                searchItems: [$0.directoryName]
            )
        }
    }
}

extension FileTree: FileTreeViewable where Component: FileTreeViewable {
    @MainActor
    public func view(for fileType: FileType) -> some View {
        content.view(for: fileType)
    }
}

extension TupleFileSystemComponent: FileTreeViewable where repeat (each T): FileTreeViewable {

    @MainActor
    public func view(for fileType: (repeat (each T).FileType)) -> some
    View {
        TupleView((repeat (each value).view(for: (each fileType))))
    }
}

extension Directory: FileTreeViewable where Component: FileTreeViewable {
    public func view(for fileType: Component.FileType) -> some View {
        DirectoryView(
            name: self.path.description,
            data: fileType,
            content: self.content,
            searchItems: [self.path.description]
        )
    }
}

struct DirectoryView<F: FileTreeViewable>: View {
    @Environment(\.directoryStyle) var directoryStyle
    @Environment(\.fileTreeSearchText) var searchText

    var name: String

    var data: F.FileType
    var searchItems: Set<String>

    var subContent: F.ViewBody

    init(
        name: String,
        data: F.FileType,
        content: F,
        searchItems: Set<String>
    ) {
        self.name = name
        self.data = data
        self.searchItems = searchItems

        self.subContent = content.view(for: data)
    }

    var body: some View {
        Group(subviews: subContent) { subviews in
            if searchText.isEmpty || !subviews.isEmpty {

                DisclosureGroup {
                    subContent
                } label: {
                    AnyView(directoryStyle.makeBody(
                        configuration: DirectoryStyleConfiguration(
                            path: name
                        )
                    ))
                }
            }
        }
    }
}

import Conversions

extension FileTreeViewable where Body: FileTreeViewable, ViewBody == Body.ViewBody, Body.FileType == FileType {
    @MainActor
    public func view(for fileType: FileType) -> Body.ViewBody {
        self.body.view(for: fileType)
    }
}

public struct _TaggedFileTreeComponent<
    Child: FileTreeViewable,
    Tag: Hashable & Sendable
>: FileTreeViewable {
    public var fileTree: Child
    public var tag: @Sendable (Child.FileType) -> Tag

    public typealias FileType = Child.FileType

    @inlinable
    public func read(from url: URL) throws -> Child.FileType {
        try fileTree.read(from: url)
    }

    @inlinable
    public func write(_ data: Child.FileType, to url: URL) throws {
        try fileTree.write(data, to: url)
    }

    @inlinable
    public func view(for fileType: FileType) -> some View {
        self.fileTree
            .view(for: fileType)
            .tag(tag(fileType))
    }
}


extension FileTreeViewable {
    public func tag<T: Hashable>(_ tag: T) -> _TaggedFileTreeComponent<Self, T> {
        _TaggedFileTreeComponent(fileTree: self, tag: { _ in tag })
    }
}

extension FileTreeViewable where FileType: Identifiable {
    public func tag<T: Hashable>(transformID: @Sendable @escaping (FileType.ID) -> T) -> _TaggedFileTreeComponent<Self, T> {
        _TaggedFileTreeComponent(fileTree: self, tag: { transformID($0.id) })
    }

    public func taggedByID() -> _TaggedFileTreeComponent<Self, FileType.ID> where FileType.ID: Sendable {
        _TaggedFileTreeComponent(fileTree: self, tag: { $0.id })
    }
}

extension Never: FileTreeComponent {
    public typealias FileType = Never
}

struct PreviewFileTree: FileTreeViewable {

    enum Tag {
        case info
        case otherInfo
    }

    var body: some FileTreeComponent<(Data, [FileContent<Data>])> & FileTreeViewable {
        Directory("Dir") {
            File("Info", "text")
                .tag(Tag.info)

            Directory("Contents") {

                File.Many(withExtension: .text)
            }
        }
    }
}




extension FileTreeViewable {
    @MainActor
    public func view(for fileType: FileType, filteringFor searchText: String) -> some View {
        self.view(for: fileType)
            .environment(\.fileTreeSearchText, searchText)
    }
}

extension EnvironmentValues {
    @Entry var fileTreeSearchText: String = ""
}


#Preview {
    @Previewable @State var selection: PreviewFileTree.Tag?

    NavigationSplitView {
        List(selection: $selection) {
            PreviewFileTree().view(
                for: (Data(), [])
            )

        }
        .contextMenu(forSelectionType: PreviewFileTree.Tag.self) { selections in
            Button("Click") {
                print("Clieck", selections)
            }
        } primaryAction: { selections in
            print("PRIMARY ACTION:", selections)
        }
    } detail: {
        switch selection {
        case .info:
            Text("Info")
        case .otherInfo:
            Text("OTHER INFO")
        case nil:
            Text("None Selected")
        }
    }
}
