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
//    associatedtype ViewBody: View

    func read(from url: URL) throws -> FileType

    func write(_ data: FileType, to url: URL) throws

    @FileTreeBuilder
    var body: Body { get }
//
//    @ViewBuilder
//    @MainActor
//    func view(for fileType: FileType) -> ViewBody
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
//extension FileTreeComponent where ViewBody == Never {
//    public var view: ViewBody {
//        return fatalError("Body of \(Self.self) should never be called")
//    }
//}

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

    public func read(from url: URL) throws -> FileContent<Data> {
        @Dependency(\.fileManagerClient) var fileManagerClient
        let fileUrl = url.appendingPathComponent(fileName, withType: fileType)

        return try FileContent(
            fileName: self.fileName,
            data: fileManagerClient.data(contentsOf: fileUrl)
        )
    }

    public func write(_ fileContent: FileContent<Data>, to url: URL) throws {
        @Dependency(\.fileManagerClient) var fileManagerClient
        let fileURL = url.appendingPathComponent(fileContent.fileName, withType: fileType)

        try fileManagerClient.writeData(data: fileContent.data, to: fileURL)
    }
}


// MARK: - Directory

public struct StaticDirectory<Component: FileTreeComponent>: FileTreeComponent {
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

public struct Directory<Component: FileTreeComponent>: FileTreeComponent {
    let path: String

    var content: Component

    public init(_ path: String, @FileTreeBuilder content: () -> Component) {
        self.path = path
        self.content = content()
    }

    // This doesn't work because when Component.FileType is a tuple, we want DirectoryContents to have multiple types from that parameter pack
    public func read(from url: URL) throws -> DirectoryContents<Component.FileType> {
        let directoryURL = url.appending(component: self.path)
        let compoents = try content.read(from: directoryURL)

        return DirectoryContents(
            directoryName: self.path,
            components: compoents
        )
    }

    public func write(_ directoryContents: DirectoryContents<Component.FileType>, to url: URL) throws {
        @Dependency(\.fileManagerClient) var fileManagerClient
        let directoryPath = url.appending(component: path.description)

        try fileManagerClient.createDirectory(at: directoryPath, withIntermediateDirectories: false)

        try content.write(directoryContents.components, to: directoryPath)
    }
}

public protocol NamedContentProtocol {
    var name: String { get }
}

extension FileContent: NamedContentProtocol {
    public var name: String {
        self.fileName
    }
}

public struct Many<Component: FileTreeComponent>: FileTreeComponent where Component.FileType: NamedContentProtocol {
    var content: @Sendable (String) -> Component

    public init(@FileTreeBuilder _ content: @Sendable @escaping (String) -> Component) {
        self.content = content
    }

    public func read(from url: URL) throws -> [Component.FileType] {
        @Dependency(\.fileManagerClient) var fileManagerClient

        let paths = try fileManagerClient.contentsOfDirectory(atPath: url)

        let components = paths.map {
            content($0.deletingPathExtension().lastPathComponent)
        }

        // TODO: Error Handling
        // These should all be run in parallel, and then collect all errors
        return try components.map {
            try $0.read(from: url)
        }.sorted {
            $0.name < $1.name
        }
    }

    public func write(_ data: [Component.FileType], to url: URL) throws {
        @Dependency(\.fileManagerClient) var fileManagerClient

        if writingToEmptyDirectory {
            try data.forEach {
                try self.content($0.name).write($0, to: url)
            }
        } else {
            reportIssue("""
            Writing to directories that may already have contents currently unsupported.
            
            This is because it is difficult to determine if a value that does not exist in the array of values getting written should be deleted because it was removed,
            or if it exists outside of the purview of the `Many { }` block and should be left alone.
            
            The semantics of Many may need to be tweaked to make this determination more clear.
            
            To allow writing to the directory, use:
            
            ```
            $writingToEmptyDirectory.withValue(true) { 
                Many { StaticFile($0, "txt").write(...) }
            }
            ```
            
            which will naively write all the contents to the directory, and not delete anything that is already there.
            """)

            // Diff the current and the old, and if theres changes, write those changes to the file system
            // This is difficult because there's dynamic content involved here.
            // I think I may need to use some sort of system where I generate the data into a temp directory,
            // Diff the new contents with the old contents, and.

            // Could this also work with some sort of flag for when you're writing to an empty directory, so we don't have to do a runaround, in a lot of circumenstances?
        }
    }
}

@TaskLocal
var writingToEmptyDirectory = false

extension Many: FileTreeViewable where Component: FileTreeViewable, Component.FileType: Identifiable, Component.FileType.ID: CustomStringConvertible {
    public func view(for values: [Component.FileType]) -> some View {
        ForEach(values) { value in
            let idString = value.id.description
            let contentInstance = content(idString)
            contentInstance.view(for: value)
        }
    }
}

// - MARK: Contents
public struct FileContent<Component> {
    public var fileName: String
    public var data: Component

    public init(fileName: String, data: Component) {
        self.fileName = fileName
        self.data = data
    }
}

extension FileContent: Identifiable {
    public var id: String { fileName }
}

public extension FileContent {
    func map<NewContent>(_ transform: (Component) throws -> NewContent) rethrows -> FileContent<NewContent> {
        try FileContent<NewContent>(
            fileName: fileName,
            data: transform(self.data)
        )
    }
}

extension FileContent: Hashable where Component: Hashable {}
extension FileContent: Sendable where Component: Sendable {}
extension FileContent: Equatable where Component: Equatable {}

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

extension StaticFile: FileTreeViewable {

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

extension File: FileTreeViewable {
    public func view(for content: FileContent<Data>) -> some View {
        FileView(
            fileName: content.fileName,
            fileType: self.fileType,
            searchItems: [self.fileName]
        )
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
    public func view(for fileType: DirectoryContents<Component.FileType>) -> some View {
        DirectoryView(
            name: self.path,
            data: fileType.components,
            content: self.content,
            searchItems: [self.path]
        )
    }
}

extension StaticDirectory: FileTreeViewable where Component: FileTreeViewable {
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
        StaticDirectory("Dir") {
            StaticFile("Info", "text")
                .tag(Tag.info)

            StaticDirectory("Contents") {

                Many {
                    File($0, .text)
                }
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
