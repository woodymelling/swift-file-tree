//
//  SwiftUI.swift
//  swift-file-tree
//
//  Created by Woodrow Melling on 11/12/24.
//

#if canImport(SwiftUI)
import SwiftUI

public protocol FileTreeViewable: FileTreeComponent {
    associatedtype ViewBody: View

    @ViewBuilder
    @MainActor
    func view(for content: Content) -> ViewBody
}

extension File: FileTreeViewable {
    public func view(for content: Data) -> some View {
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
    public func view(for directories: [DirectoryContent<Component.Content>]) -> some View {
        ForEach(directories, id: \.directoryName) {
            DirectoryView(
                name: $0.directoryName,
                data: $0.components,
                component: self.component,
                searchItems: [$0.directoryName]
            )
        }
    }
}

extension FileTree: FileTreeViewable where Component: FileTreeViewable {
    @MainActor
    public func view(for content: Content) -> some View {
        component.view(for: content)
    }
}

extension TupleFileSystemComponent: FileTreeViewable where repeat (each T): FileTreeViewable {

    @MainActor
    public func view(for content: (repeat (each T).Content)) -> some
    View {
        TupleView((repeat (each value).view(for: (each content))))
    }
}

extension Directory: FileTreeViewable where Component: FileTreeViewable {
    public func view(for content: Component.Content) -> some View {
        DirectoryView(
            name: self.path.description,
            data: content,
            component: self.component,
            searchItems: [self.path.description]
        )
    }
}

struct DirectoryView<F: FileTreeViewable>: View {
    @Environment(\.directoryStyle) var directoryStyle
    @Environment(\.fileTreeSearchText) var searchText

    var name: String

    var data: F.Content
    var searchItems: Set<String>

    var subContent: F.ViewBody

    init(
        name: String,
        data: F.Content,
        component: F,
        searchItems: Set<String>
    ) {
        self.name = name
        self.data = data
        self.searchItems = searchItems

        self.subContent = component.view(for: data)
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

extension FileTreeViewable where Body: FileTreeViewable, ViewBody == Body.ViewBody, Body.Content == Content {
    @MainActor
    public func view(for content: Content) -> Body.ViewBody {
        self.body.view(for: content)
    }
}

public struct _TaggedFileTreeComponent<
    Child: FileTreeViewable,
    Tag: Hashable & Sendable
>: FileTreeViewable {
    public var fileTree: Child
    public var tag: @Sendable (Child.Content) -> Tag

    public typealias Content = Child.Content

    @inlinable
    public func read(from url: URL) throws -> Child.Content {
        try fileTree.read(from: url)
    }

    @inlinable
    public func write(_ data: Child.Content, to url: URL) throws {
        try fileTree.write(data, to: url)
    }

    @inlinable
    public func view(for content: Content) -> some View {
        self.fileTree
            .view(for: content)
            .tag(tag(content))
    }
}


extension FileTreeViewable {
    public func tag<T: Hashable>(_ tag: T) -> _TaggedFileTreeComponent<Self, T> {
        _TaggedFileTreeComponent(fileTree: self, tag: { _ in tag })
    }
}

extension FileTreeViewable where Content: Identifiable {
    public func tag<T: Hashable>(transformID: @Sendable @escaping (Content.ID) -> T) -> _TaggedFileTreeComponent<Self, T> {
        _TaggedFileTreeComponent(fileTree: self, tag: { transformID($0.id) })
    }

    public func taggedByID() -> _TaggedFileTreeComponent<Self, Content.ID> where Content.ID: Sendable {
        _TaggedFileTreeComponent(fileTree: self, tag: { $0.id })
    }
}

extension Never: FileTreeComponent {
    public typealias Content = Never
}

extension FileTreeViewable {
    @MainActor
    public func view(for content: Content, filteringFor searchText: String) -> some View {
        self.view(for: content)
            .environment(\.fileTreeSearchText, searchText)
    }
}

extension EnvironmentValues {
    @Entry var fileTreeSearchText: String = ""
}



// MARK: - File
protocol FileStyle {
    associatedtype Body: View
    typealias Configuration = FileStyleConfiguration

    @ViewBuilder
    @MainActor
    func makeBody(configuration: Configuration) -> Body
}

public struct FileStyleConfiguration {
    let fileName: String
    let fileExtension: String
    let isLoading: Bool
}

struct DefaultFileStyle: FileStyle {

    func makeBody(configuration: Configuration) -> some View {
        Label {
            Text(configuration.fileName)
        } icon: {
            Image(systemName: "doc")
        }
    }
}

struct FileView: View {
    @Environment(\.fileStyle) var fileStyle
    @Environment(\.fileTreeSearchText) var searchText

    var fileName: String
    var fileType: UTFileExtension
    var searchItems: Set<String>

    var containsSearchTerm: Bool {
        searchItems.contains(where: {
            $0.range(of: searchText, options: .caseInsensitive) != nil
        }) 
    }

    var body: some View {
        if searchText.isEmpty || containsSearchTerm {
            AnyView(
                fileStyle.makeBody(
                    configuration: FileStyleConfiguration(
                        fileName: self.fileName,
                        fileExtension: self.fileType.identifier,
                        isLoading: false
                    )
                )
            )
        } else {
            EmptyView()
        }
    }
}

extension EnvironmentValues {
    @Entry var fileStyle: any FileStyle = DefaultFileStyle()
    @Entry var directoryStyle: any DirectoryStyle = DefaultDirectoryStyle()
}

// MARK: - Directory
protocol DirectoryStyle {
    associatedtype Body: View
    typealias Configuration = DirectoryStyleConfiguration

    @ViewBuilder
    @MainActor
    func makeBody(configuration: Configuration) -> Body
}

public struct DirectoryStyleConfiguration {
    let path: String
}

struct DefaultDirectoryStyle: DirectoryStyle {
    func makeBody(configuration: Configuration) -> some View {
        Label(configuration.path, systemImage: "folder")
    }
}

// MARK: - FileWrapper

public extension FileTreeComponent {
    func read(from fileWrapper: FileWrapper) throws -> Content {
        let tempDirectoryURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer {
            try? FileManager.default.removeItem(at: tempDirectoryURL)
        }
        try fileWrapper.write(to: tempDirectoryURL, options: [], originalContentsURL: nil)
        return try self.read(from: tempDirectoryURL)
    }

    func write(_ data: Content) throws -> FileWrapper {
        let tempDirectoryURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer {
            try? FileManager.default.removeItem(at: tempDirectoryURL)
        }

        try $writingToEmptyDirectory.withValue(true) {
            try self.write(data, to: tempDirectoryURL)
        }

        let fileWrapper = try FileWrapper(url: tempDirectoryURL, options: .immediate)
        return fileWrapper
    }
}


// MARK: - Preview
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

#Preview {
    @Previewable @State var selection: PreviewFileTree.Tag?

    NavigationSplitView {
        List(selection: $selection) {
            PreviewFileTree().view(
                for: (Data(), [FileContent(fileName: "File1", data: Data())])
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
#endif


