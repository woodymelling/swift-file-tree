//
//  SwiftUI.swift
//  swift-file-tree
//
//  Created by Woodrow Melling on 11/12/24.
//

import SwiftUI

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
    let fileExtension: FileType
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

extension EnvironmentValues {
    @Entry var fileStyle: any FileStyle = DefaultFileStyle()
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
    let content: any View
}

struct DefaultDirectoryStyle: DirectoryStyle {

    func makeBody(configuration: Configuration) -> some View {
        DisclosureGroup {
            AnyView(configuration.content)
        } label: {
            Label(configuration.path, systemImage: "folder")
        }
    }
}



extension EnvironmentValues {
    @Entry var directoryStyle: any DirectoryStyle = DefaultDirectoryStyle()
}

private struct Content: View {
    var body: some View {
        FileTreeView(
            for: (Data(), Data()),
            using: PreviewFileTree()
        )
    }
}

#Preview {
    NavigationSplitView {
        List {
            Content()
        }
    } detail: {
        Text("Content")
    }
}
