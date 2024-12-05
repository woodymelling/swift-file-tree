//
//  Directory.swift
//  swift-file-tree
//
//  Created by Woodrow Melling on 12/5/24.
//

import Foundation
import IssueReporting

public struct Directory<Component: FileTreeComponent>: FileTreeComponent {
    let path: StaticString
    var component: Component

    public init(_ path: StaticString, @FileTreeBuilder component: () -> Component) {
        self.path = path
        self.component = component()
    }

    public func read(from url: URL) throws -> Component.Content {
        let directoryURL = url.appending(component: self.path.description)

        return try component.read(from: directoryURL)
    }

    public func write(_ data: Component.Content, to url: URL) throws {
        let directoryPath = url.appending(component: path.description)

        if !FileManager.default.fileExists(atPath: directoryPath.path()) {
            try FileManager.default.createDirectory(at: directoryPath, withIntermediateDirectories: false)
        }

        try component.write(data, to: directoryPath)
    }
}


@TaskLocal
public var writingToEmptyDirectory = false


extension Directory {
    public struct Many: FileTreeComponent {
        public typealias Content = [DirectoryContent<Component.Content>]

        var component: Component

        public init(@FileTreeBuilder component: @Sendable () -> Component) {
            self.component = component()
        }

        public func read(from url: URL) throws -> [DirectoryContent<Component.Content>] {

            let directoryNames = try FileManager.default.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: [],
                options: .skipsHiddenFiles
            ).filter(\.hasDirectoryPath)

            return try directoryNames.map {
                let contents = try component.read(from: $0)
                return DirectoryContent(directoryName: $0.lastPathComponent, components: contents)
            }.sorted(by: { $0.directoryName < $1.directoryName })
        }

        public func write(_ data: [DirectoryContent<Component.Content>], to url: URL) throws {
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



            if !FileManager.default.fileExists(atPath: url.path()) {
                try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            }

            for directoryContent in data {
                let directoryURL = url.appendingPathComponent(directoryContent.directoryName)

                if !FileManager.default.fileExists(atPath: directoryURL.path()) {
                    try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: false)
                }

                try component.write(directoryContent.components, to: directoryURL)
            }
        }
    }

}

// MARK: DirectoryContent
public struct DirectoryContent<T>  {
    public var directoryName: String
    public var components: T

    public init(directoryName: String, components: T) {
        self.directoryName = directoryName
        self.components = components
    }
}

extension DirectoryContent: Equatable where T: Equatable {}
extension DirectoryContent: Hashable where T: Hashable {}
extension DirectoryContent: Sendable where T: Sendable {}
public extension DirectoryContent {
    func map<NewComponents>(_ transform: (T) throws -> NewComponents) rethrows -> DirectoryContent<NewComponents> {
        try DirectoryContent<NewComponents>(
            directoryName: directoryName,
            components: transform(self.components)
        )
    }
}
