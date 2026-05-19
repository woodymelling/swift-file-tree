import Foundation

public struct FileTreeWriteContext: Sendable {
    static let empty = FileTreeWriteContext(
        sourceURL: nil,
        graph: .init(),
        rootPath: nil
    )

    public var sourceURL: URL?
    public var graph: SourceGraph
    public var rootPath: SourceGraph.Path?

    private init(
        sourceURL: URL?,
        graph: SourceGraph,
        rootPath: SourceGraph.Path? = nil
    ) {
        self.sourceURL = sourceURL
        self.graph = graph
        self.rootPath = rootPath
    }

    public init(
        sourceURL: URL,
        graph: SourceGraph = .init(),
        rootPath: SourceGraph.Path? = nil
    ) {
        self.init(sourceURL: .some(sourceURL), graph: graph, rootPath: rootPath)
    }

    public init(
        graph: SourceGraph,
        rootPath: SourceGraph.Path? = nil
    ) {
        self.init(sourceURL: nil, graph: graph, rootPath: rootPath)
    }

    public func data(at path: SourceGraph.Path) throws -> Data? {
        guard let sourceURL else { return nil }

        let fileURL = sourceURL.appending(path: path.rawValue)
        guard FileManager.default.fileExists(atPath: fileURL.path()) else {
            return nil
        }
        return try Data(contentsOf: fileURL)
    }

    public func rootData() throws -> Data? {
        guard let path = rootPath ?? graph.rootPath else { return nil }
        return try data(at: path)
    }

    public func text(
        at path: SourceGraph.Path,
        encoding: String.Encoding = .utf8
    ) throws -> String? {
        guard let data = try data(at: path) else { return nil }
        return String(data: data, encoding: encoding)
    }

    public func rootText(encoding: String.Encoding = .utf8) throws -> String? {
        guard let data = try rootData() else { return nil }
        return String(data: data, encoding: encoding)
    }

    public func descending(into component: String) -> Self {
        var copy = self
        copy.sourceURL = sourceURL?.appending(component: component)
        copy.rootPath = nil
        return copy
    }

    public func rooted<Element>(at element: Element) -> Self {
        guard let rootedElement = element as? any SourceGraph.RootedElement
        else { return self }

        var copy = self
        copy.rootPath = rootedElement.sourceGraphIdentity.path
        copy.graph = graph.rooted(at: element)
        return copy
    }

}

extension SourceGraph {
    var rootPath: Path? {
        guard let root, let node = nodes[root] else { return nil }
        return node.identity.path
    }
}

extension SourceGraph.Node.Identity {
    var path: SourceGraph.Path? {
        switch self {
        case let .directory(path), let .file(path):
            return path

        case .repository, .logical:
            return nil
        }
    }
}
