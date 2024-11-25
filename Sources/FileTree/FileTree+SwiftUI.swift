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

struct FileView: View {
    @Environment(\.fileStyle) var fileStyle
    @Environment(\.fileTreeSearchText) var searchText

    var fileName: String
    var fileType: FileType
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
                        fileExtension: self.fileType,
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
