//
//  Directory.swift
//  swift-file-tree
//
//  Created by Woodrow Melling on 12/5/24.
//

import Foundation

public struct Directory<Component: FileTreeReader>: FileTreeReader {
    let path: StaticString
    var component: Component

    public init(_ path: StaticString, @FileTreeBuilder component: () -> Component) {
        self.path = path
        self.component = component()
    }

    public func read(from url: URL) throws -> FileTreeResult<Component.Content> {
        let directoryURL = url.appending(component: self.path.description)

        let result = try component.read(from: directoryURL)
        let prefix = SourceGraph.Path(rawValue: self.path.description)
        let directoryIdentity = SourceGraph.Node.Identity.directory(prefix)
        var graph = result.graph.prefixingPaths(with: prefix)
        let directoryID = graph.insert(directoryIdentity)

        for childID in graph.rootNodeIDs where childID != directoryID {
            graph.connect(directoryID, to: childID, kind: .contains)
        }
        graph.root = directoryID

        return FileTreeResult(
            output: result.output,
            graph: graph,
            diagnostics: result.diagnostics.prefixingPaths(with: prefix)
        )
    }

    // public func write(_ data: Component.Content, to url: URL) throws {
    //     let directoryPath = url.appending(component: path.description)
    //
    //     if !FileManager.default.fileExists(atPath: directoryPath.path()) {
    //         try FileManager.default.createDirectory(at: directoryPath, withIntermediateDirectories: false)
    //     }
    //
    //     try component.write(data, to: directoryPath)
    // }
}

extension Directory: FileTreeWriter where Component: FileTreeWriter {
    public func write(_ content: Component.Content, to url: URL) throws -> FileTreeResult<Component.Content> {
        try write(content, to: url, context: .empty)
    }

    public func write(
        _ content: Component.Content,
        to url: URL,
        context: FileTreeWriteContext
    ) throws -> FileTreeResult<Component.Content> {
        let directoryURL = url.appending(component: self.path.description)

        if !FileManager.default.fileExists(atPath: directoryURL.path()) {
            try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: false)
        }

        let result = try component.write(
            content,
            to: directoryURL,
            context: context.descending(into: self.path.description)
        )
        let prefix = SourceGraph.Path(rawValue: self.path.description)
        let directoryIdentity = SourceGraph.Node.Identity.directory(prefix)
        var graph = result.graph.prefixingPaths(with: prefix)
        let directoryID = graph.insert(directoryIdentity)

        for childID in graph.rootNodeIDs where childID != directoryID {
            graph.connect(directoryID, to: childID, kind: .contains)
        }
        graph.root = directoryID

        return FileTreeResult(
            output: result.output,
            graph: graph,
            diagnostics: result.diagnostics.prefixingPaths(with: prefix)
        )
    }
}


@TaskLocal
public var writingToEmptyDirectory = false


extension Directory {
    public struct Many: FileTreeReader {
        public typealias Content = [DirectoryContent<Component.Content>]

        var component: Component

        public init(@FileTreeBuilder component: @Sendable () -> Component) {
            self.component = component()
        }

        public func read(from url: URL) throws -> FileTreeResult<[DirectoryContent<Component.Content>]> {

            let directoryNames = try FileManager.default.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: [],
                options: .skipsHiddenFiles
            ).filter(\.hasDirectoryPath)

            var contents: [DirectoryContent<Component.Content>] = []
            var diagnostics = DiagnosticReport<FileTreeLocation>()
            var graph = SourceGraph()
            var isInvalid = false

            for directoryURL in directoryNames {
                let directoryName = directoryURL.lastPathComponent
                let result = try component.read(from: directoryURL)
                let prefix = SourceGraph.Path(rawValue: directoryName)
                diagnostics.append(contentsOf: result.diagnostics.prefixingPaths(with: prefix))

                var childGraph = result.graph.prefixingPaths(with: prefix)
                let directoryID = childGraph.insert(.directory(prefix))
                for childID in childGraph.rootNodeIDs where childID != directoryID {
                    childGraph.connect(directoryID, to: childID, kind: .contains)
                }
                childGraph.root = directoryID
                graph.append(childGraph)

                switch result.output {
                case let .value(value):
                    contents.append(DirectoryContent(directoryName: directoryName, components: value))
                case .invalid:
                    isInvalid = true
                }
            }

            guard !isInvalid && !diagnostics.hasErrors else {
                return .invalid(graph: graph, diagnostics: diagnostics)
            }

            return .value(contents.sorted(by: { $0.directoryName < $1.directoryName }), graph: graph, diagnostics: diagnostics)
        }

        // public func write(_ data: [DirectoryContent<Component.Content>], to url: URL) throws {
        //     guard writingToEmptyDirectory
        //     else {
        //         reportIssue("""
        //         Writing a `Many` to a directory that may already have contents currently unsupported.
        //
        //         This is because it is difficult to determine if a value that does not exist in the array of values getting written should be deleted because it was removed,
        //         or if it exists outside of the purview of the `Many { }` block and should be left alone.
        //
        //         The semantics of Many may need to be tweaked to make this determination more clear.
        //
        //         To allow writing to the directory, use:
        //
        //         ```
        //         $writingToEmptyDirectory.withValue(true) { 
        //             Directories { StaticFile($0, "txt") }.write(...)
        //         }
        //         ```
        //
        //         which will naively write all the contents to the directory, and not delete anything that is already there.
        //         """)
        //         return
        //     }
        //
        //
        //
        //     if !FileManager.default.fileExists(atPath: url.path()) {
        //         try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        //     }
        //
        //     for directoryContent in data {
        //         let directoryURL = url.appendingPathComponent(directoryContent.directoryName)
        //
        //         if !FileManager.default.fileExists(atPath: directoryURL.path()) {
        //             try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: false)
        //         }
        //
        //         try component.write(directoryContent.components, to: directoryURL)
        //     }
        // }
    }

}

extension Directory.Many: FileTreeWriter where Component: FileTreeWriter {
    public func write(
        _ content: [DirectoryContent<Component.Content>],
        to url: URL
    ) throws -> FileTreeResult<[DirectoryContent<Component.Content>]> {
        try write(content, to: url, context: .empty)
    }

    public func write(
        _ content: [DirectoryContent<Component.Content>],
        to url: URL,
        context: FileTreeWriteContext
    ) throws -> FileTreeResult<[DirectoryContent<Component.Content>]> {
        if !FileManager.default.fileExists(atPath: url.path()) {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }

        var outputs: [DirectoryContent<Component.Content>] = []
        var diagnostics = DiagnosticReport<FileTreeLocation>()
        var graph = SourceGraph()
        var isInvalid = false

        for directoryContent in content {
            let directoryURL = url.appendingPathComponent(directoryContent.directoryName)

            if !FileManager.default.fileExists(atPath: directoryURL.path()) {
                try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: false)
            }

            let result = try component.write(
                directoryContent.components,
                to: directoryURL,
                context: context.descending(into: directoryContent.directoryName)
            )

            let directoryIdentity = SourceGraph.Node.Identity.directory(
                .init(rawValue: directoryContent.directoryName)
            )
            let prefix = SourceGraph.Path(rawValue: directoryContent.directoryName)
            diagnostics.append(contentsOf: result.diagnostics.prefixingPaths(with: prefix))
            var childGraph = result.graph.prefixingPaths(
                with: prefix
            )
            let directoryID = childGraph.insert(directoryIdentity)

            for childID in childGraph.rootNodeIDs where childID != directoryID {
                childGraph.connect(directoryID, to: childID, kind: .contains)
            }
            childGraph.root = directoryID
            graph.append(childGraph)

            switch result.output {
            case let .value(components):
                outputs.append(
                    DirectoryContent(
                        directoryName: directoryContent.directoryName,
                        components: components
                    )
                )
            case .invalid:
                isInvalid = true
            }
        }

        guard !isInvalid && !diagnostics.hasErrors else {
            return .invalid(graph: graph, diagnostics: diagnostics)
        }

        return .value(outputs, graph: graph, diagnostics: diagnostics)
    }
}

extension Directory {
    public struct Optional: FileTreeReader {
        public typealias Content = Component.Content?
        let path: StaticString
        var component: Component

        public init(_ path: StaticString, @FileTreeBuilder component: () -> Component) {
            self.path = path
            self.component = component()
        }
//
        public func read(from url: URL) throws -> FileTreeResult<Component.Content?> {
            let directoryURL = url.appending(component: self.path.description)
            func directoryExistsAtPath(_ path: String) -> Bool {
                var isDirectory : ObjCBool = true
                let exists = FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory)
                return exists && isDirectory.boolValue
            }
            guard directoryExistsAtPath(directoryURL.path())
            else { return .value(nil) }

            let result = try component.read(from: directoryURL)
            let prefix = SourceGraph.Path(rawValue: self.path.description)
            let directoryIdentity = SourceGraph.Node.Identity.directory(prefix)
            var graph = result.graph.prefixingPaths(with: prefix)
            let directoryID = graph.insert(directoryIdentity)

            for childID in graph.rootNodeIDs where childID != directoryID {
                graph.connect(directoryID, to: childID, kind: .contains)
            }
            graph.root = directoryID

            return FileTreeResult(
                output: result.output.map { Swift.Optional.some($0) },
                graph: graph,
                diagnostics: result.diagnostics.prefixingPaths(with: prefix)
            )
        }
    }
}

extension Directory.Optional: FileTreeWriter where Component: FileTreeWriter {
    public func write(
        _ content: Component.Content?,
        to url: URL
    ) throws -> FileTreeResult<Component.Content?> {
        try write(content, to: url, context: .empty)
    }

    public func write(
        _ content: Component.Content?,
        to url: URL,
        context: FileTreeWriteContext
    ) throws -> FileTreeResult<Component.Content?> {
        guard let content else {
            return .value(nil)
        }

        let directoryURL = url.appending(component: self.path.description)
        if !FileManager.default.fileExists(atPath: directoryURL.path()) {
            try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: false)
        }

        let result = try component.write(
            content,
            to: directoryURL,
            context: context.descending(into: self.path.description)
        )
        let prefix = SourceGraph.Path(rawValue: self.path.description)
        let directoryIdentity = SourceGraph.Node.Identity.directory(prefix)
        var graph = result.graph.prefixingPaths(with: prefix)
        let directoryID = graph.insert(directoryIdentity)

        for childID in graph.rootNodeIDs where childID != directoryID {
            graph.connect(directoryID, to: childID, kind: .contains)
        }
        graph.root = directoryID

        return FileTreeResult(
            output: result.output.map { Swift.Optional.some($0) },
            graph: graph,
            diagnostics: result.diagnostics.prefixingPaths(with: prefix)
        )
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
