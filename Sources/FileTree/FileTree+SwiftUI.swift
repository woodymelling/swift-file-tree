//
//  SwiftUI.swift
//  swift-file-tree
//
//  Created by Woodrow Melling on 11/12/24.
//

#if canImport(SwiftUI)
import SwiftUI

public protocol FileTreeViewable: FileTreeComponent {
    associatedtype FileType
    associatedtype ViewBody: View
    @ViewBuilder func view(for fileType: FileType) -> ViewBody
}

extension StaticFile: FileTreeViewable {
    public func view(for fileType: Data) -> some View {
        Label("\(self.fileName)", systemImage: "doc")
    }
}

extension File: FileTreeViewable {
    public func view(for fileType: FileContent<Data>) -> some View {
        Label("\(self.fileName)", systemImage: "doc")
    }
}

extension FileTree: FileTreeViewable where Content: FileTreeViewable {
    public func view(for fileType: FileType) -> some View {
        content.view(for: fileType)
    }
}

extension TupleFileSystemComponent: FileTreeViewable where repeat each T: FileTreeViewable {

    public func view(for fileType: (repeat (each T).FileType)) -> some
    View {
        let values = (repeat (each value).view(for: (each fileType)))
        TupleView(values)

//        Text("Hit")
    }
//
//    func getViews(for fileType: (repeat (each T).FileType)) -> some
//    View {
//        var views: [AnyView] = []
//
//        for v in repeat (each value).view(for: each fileType) {
//            views.append(AnyView(v))
//        }
//
//        return ForEach(views, id: \.self) { view in
//            view
//        }
//    }
}

//
//extension Directory: FileTreeViewable where Content: FileTreeViewable {
//    public var view: some View {
//        DisclosureGroup(path) {
//            content.view
//        }
//    }
//}

extension StaticDirectory: FileTreeViewable where Content: FileTreeViewable {
    public func view(for fileType: Content.FileType) -> some View {
        DisclosureGroup(self.path.description) {
            content.view(for: fileType)
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

@preconcurrency import Parsing

struct PreviewFileTree: FileTreeComponent {

    var body: some FileTreeComponent {
        StaticDirectory("Dir") {
            StaticFile("Info", .text)
            StaticFile("OtherInfo", .text)
        }
    }
}

private struct Content: View {
    var body: some View {
        FileTreeView(
            for: (Data(), Data()),
            using: TupleFileSystemComponent(
                StaticFile("Info", .text),
                StaticFile("OtherInfo", .text)
            )
        )
    }
}

#Preview {
    Content()
}

#endif
