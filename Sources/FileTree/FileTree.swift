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
//    associatedtype ViewBody: View

    func read(from url: URL) async throws -> FileType

    func write(_ data: FileType, to url: URL) async throws

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

public struct _File: FileTreeComponent {
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

extension Many: FileTreeViewable where Content: FileTreeViewable, Content.FileType: Identifiable, Content.FileType.ID: CustomStringConvertible {
    public func view(for values: [Content.FileType]) -> some View {
        ForEach(values) { value in
            let idString = value.id.description
            let contentInstance = content(idString)
            contentInstance.view(for: value)
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

extension FileTree: FileTreeViewable where Content: FileTreeViewable {
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


extension Directory: FileTreeViewable where Content: FileTreeViewable {
    public func view(for fileType: DirectoryContents<Content.FileType>) -> some View {
        DirectoryView(
            name: self.path,
            data: fileType.components,
            content: self.content,
            searchItems: [self.path]
        )
    }
}

extension StaticDirectory: FileTreeViewable where Content: FileTreeViewable {
    public func view(for fileType: Content.FileType) -> some View {
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
            if !subviews.isEmpty {

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




public struct FileTreeView<FileTree: FileTreeViewable>: View {
    public init(for value: FileTree.FileType, using fileTree: FileTree) {
        self.value = value
        self.fileTree = fileTree
    }

    public var value: FileTree.FileType
    public var fileTree: FileTree

    public var body: some View {
        fileTree.view(for: value)
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
    public func read(from url: URL) async throws -> Child.FileType {
        try await fileTree.read(from: url)
    }

    @inlinable
    public func write(_ data: Child.FileType, to url: URL) async throws {
        try await fileTree.write(data, to: url)
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

    var body: some FileTreeComponent<(Data, Data)> & FileTreeViewable {
        StaticDirectory("Dir") {
            StaticFile("Info", "text")
                .tag(Tag.info)

            StaticFile("OtherInfo", "text")
                .tag(Tag.otherInfo)
        }
    }
}




private struct Content: View {
    var body: some View {
        FileTreeView(
            for: (Data(), Data()),
            using: PreviewFileTree()
        )
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
            Content()
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
