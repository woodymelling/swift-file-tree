//
//  SwiftUI.swift
//  swift-file-tree
//
//  Created by Woodrow Melling on 11/12/24.
//

#if canImport(SwiftUI)
import SwiftUI
import Foundation

public protocol FileTreeViewable<Content>: FileTreeComponent {
    associatedtype ViewBody: View

    @ViewBuilder
    @MainActor
    func view(for content: Content) -> ViewBody
}

extension File: FileTreeViewable {
    public func view(for content: Data) -> some View {
        FileContentView(fileName: self.fileName.description)
    }
}

extension File.Many: FileTreeViewable {
    public func view(for files: [FileContent<Data>]) -> some View {
        ForEach(files, id: \.fileName) {
            FileContentView(fileName: $0.fileName)
        }
    }
}

extension Directory.Many: FileTreeViewable where Component: FileTreeViewable {
    public func view(for directories: [DirectoryContent<Component.Content>]) -> some View {
        ForEach(directories, id: \.directoryName) {
            DirectoryView(
                name: $0.directoryName,
                data: $0.components,
                component: self.component
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

//
// extension TupleFileSystemComponent: FileTreeViewable where repeat (each T): FileTreeViewable {
//
//     @MainActor
//     public func view(for content: (repeat (each T).Content)) -> some
//     View {
//         TupleView((repeat (each value).view(for: (each content))))
//     }
// }
extension PairFileTreeComponent: FileTreeViewable where F1: FileTreeViewable, F2: FileTreeViewable {
    @MainActor
    public func view(for content: (F1.Content, F2.Content)) -> some View {
        TupleView((value.0.view(for: (content.0)), value.1.view(for: (content.1))))
    }
}

extension Directory: FileTreeViewable where Component: FileTreeViewable {
    public func view(for content: Component.Content) -> some View {
        @Environment(\.directory) var fileStyle
        DirectoryView(
            name: self.path.description,
            data: content,
            component: self.component
        )
    }
}

extension EnvironmentValues {
    @Entry var directory: Bool = false
}

struct DirectoryView<F: FileTreeViewable>: View {
    @Environment(\.directoryStyle) var directoryStyle

    var name: String

    var data: F.Content

    var subContent: F.ViewBody

    init(
        name: String,
        data: F.Content,
        component: F
    ) {
        self.name = name
        self.data = data

        self.subContent = component.view(for: data)
    }

    var body: some View {
        DisclosureGroup {
            subContent
        } label: {
            AnyView(directoryStyle.makeBody(
                configuration: DirectoryStyleConfiguration(
                    path: name
                )
            ))
        }
        .tag(PreviewFileTree.Tag.info)
    }
}


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
//            .compositingGroup()
            .tag(tag(content))
    }
}


public struct _TaggedArrayFileTreeComponent<
    Component: FileTreeViewable,
    Element,
    Tag: Hashable
>: FileTreeViewable where Component.Content == Array<Element> {
    public typealias Content = Component.Content

    let original: Component
    let tag: (Component.Content.Element) -> Tag

    public func read(from url: URL) throws -> Content {
        try original.read(from: url)
    }

    public func write(_ data: Content, to url: URL) throws {
        try original.write(data, to: url)
    }

    /**
    Workaround: `original.view(for:)` generates a collection of views, likely using a `ForEach` internally.
    SwiftUI does not allow direct access to those individual child views to modify them, such as applying `.tag`.
    To work around this, we call `original.view(for:)` multiple times, passing single-element arrays `[value]`.
    This forces `original` to render one child view at a time, allowing us to tag each view individually.

    --- Implications ---
    1. **Redundant Calls:** Calling `original.view(for:)` for each child duplicates work
    2. **Double Iteration:** The array is iterated twice: once here and once internally by `original.view(for:)`.
    3. **Behavior Mismatch:** If `original.view(for:)` depends on the full array (e.g., sorting or grouping), passing single-element arrays may cause inconsistencies.

    This approach works but should be revisited if SwiftUI offers better ways to intercept or modify child views.

     I attempted to use `Group(subviews: ) { }` and re-ForEaching to solve this problem, but it caused bugs where the contents of a directory got highlighted when the directory itself got highlighted
     This was maybe because the tag on the parent view was somehow getting applied to each child view that was gener
     */
    public func view(for values: [Content.Element]) -> some View {
        ForEach(values.map { ($0, tag($0)) }, id: \.1) { value, tag in
            original
                .view(for: [value])
                .tag(tag)
        }
    }
}

extension FileTreeViewable {
    public func tag<T: Hashable>(_ tag: T) -> _TaggedFileTreeComponent<Self, T> {
        _TaggedFileTreeComponent(fileTree: self, tag: { _ in tag })
    }

    public func tag<Element, T: Hashable>(
        _ tag: @escaping (Content.Element) -> T
    ) -> _TaggedArrayFileTreeComponent<Self, Element, T> where Content == Array<Element> {
        _TaggedArrayFileTreeComponent(original: self, tag: tag)
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

struct FileContentView: View {
    @Environment(\.fileStyle) var fileStyle

    var fileName: String

    var body: some View {
        AnyView(fileStyle.makeBody(
            configuration: FileStyleConfiguration(fileName: self.fileName)
        ))
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

//
//extension _MappedFileTreeComponent: FileTreeViewable where Component: FileTreeViewable {
//
//    public func view(for content: [C.Output]) -> some View {
//        original.view(for: content.map { try! conversion.unapply($0) })
//    }
//
//}

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

import Conversions

// MARK: - Preview
struct PreviewFileTree: FileTreeViewable {
    enum Tag: Hashable {
        case info
        case info2
        case info3
        case list(String)
        case contents
        case dir
    }

    var body: some FileTreeViewable<([FileContent<Data>])> {
        Directory("Dir") {

            File.Many(withExtension: "txt")
                .map(FileContentConversion(Conversions.Identity<Data>()))
                .tag { Tag.list($0.fileName) }
//            .tag(Tag.contents)
        }
//        .tag(Tag.dir)
    }
}

#Preview {
    @Previewable @State var selection: Set<PreviewFileTree.Tag> = []

    NavigationSplitView {
        List(selection: $selection) {
            PreviewFileTree().view(
                for: (
//                    Data(),
//                    Data(),
//                    Data(),
                    [
                        FileContent(fileName: "File1", data: Data()),
                        FileContent(fileName: "File2", data: Data())
                    ]
                )
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
        Text("\(selection)")
    }
}



#Preview("Vanilla") {
    @Previewable @State var selection: Set<PreviewFileTree.Tag> = []

    NavigationSplitView {
        List(selection: $selection) {
            Text("Info")
                .tag(PreviewFileTree.Tag.info)

            Text("Info2")
                .tag(PreviewFileTree.Tag.info2)

            DisclosureGroup("Info3") {
                ForEach(1..<5, id: \.self) { id in
                    Text("Info")
                        .tag(PreviewFileTree.Tag.list(String(id)))

                }
            }
            .tag(PreviewFileTree.Tag.info3)
        }
        .contextMenu(forSelectionType: PreviewFileTree.Tag.self) { selections in
            Button("Click") {
                print("Clieck", selections)
            }
        } primaryAction: { selections in
            print("PRIMARY ACTION:", selections)
        }
    } detail: {
        Text("\(selection)")
    }
}
#endif
