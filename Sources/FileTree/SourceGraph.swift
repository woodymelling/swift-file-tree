import Foundation

public struct SourceGraph: Equatable, Sendable {
    public var root: Node.ID?
    public var nodes: [Node.ID: Node]
    public var edges: [Edge]

    public init(
        root: Node.ID? = nil,
        nodes: [Node.ID: Node] = [:],
        edges: [Edge] = []
    ) {
        self.root = root
        self.nodes = nodes
        self.edges = edges
    }
}

extension SourceGraph {
    public static func node(_ identity: Node.Identity) -> Self {
        var graph = Self()
        let node = Node(identity: identity)
        graph.root = node.id
        graph.nodes[node.id] = node
        return graph
    }

    public mutating func insert(_ identity: Node.Identity) -> Node.ID {
        let node = Node(identity: identity)
        nodes[node.id] = node
        return node.id
    }

    public mutating func append(_ other: SourceGraph) {
        nodes.merge(other.nodes) { current, _ in current }
        edges.append(contentsOf: other.edges)
    }

    public mutating func connect(_ source: Node.ID, to target: Node.ID, kind: Edge.Kind) {
        edges.append(.init(source: source, target: target, kind: kind))
    }

    public var rootNodeIDs: [Node.ID] {
        if let root {
            return [root]
        }

        let containedNodeIDs = Set(edges.filter { $0.kind == .contains }.map(\.target))
        return nodes.keys.filter { !containedNodeIDs.contains($0) }.sorted { $0.rawValue < $1.rawValue }
    }

    public func containsNode(_ identity: Node.Identity) -> Bool {
        nodes[Node.ID(identity)] != nil
    }

    public func containsEdge(from source: Node.Identity, to target: Node.Identity, kind: Edge.Kind) -> Bool {
        edges.contains(
            .init(
                source: Node.ID(source),
                target: Node.ID(target),
                kind: kind
            )
        )
    }

    public mutating func insertLogicalSource(
        kind: Node.Logical.KindName,
        key: Node.Logical.Key?,
        parsedFrom source: Node.ID?
    ) -> Node.ID {
        let logicalID = insert(.logical(kind: kind, key: key))

        if let source {
            connect(source, to: logicalID, kind: .parsedFrom)
        }

        return logicalID
    }

    public func prefixingPaths(with prefix: Path) -> Self {
        var graph = SourceGraph()
        var idMap: [Node.ID: Node.ID] = [:]

        for node in nodes.values {
            let prefixedNode = Node(identity: node.identity.prefixingPath(with: prefix))
            graph.nodes[prefixedNode.id] = prefixedNode
            idMap[node.id] = prefixedNode.id
        }

        graph.edges = edges.compactMap { edge in
            guard let source = idMap[edge.source], let target = idMap[edge.target] else {
                return nil
            }
            return Edge(source: source, target: target, kind: edge.kind)
        }

        graph.root = root.flatMap { idMap[$0] }
        return graph
    }

    public func location(for handle: Handle) -> Location? {
        var visitedNodeIDs = Set<Node.ID>()
        return location(for: handle.nodeID, visitedNodeIDs: &visitedNodeIDs)
    }

    private func location(
        for nodeID: Node.ID,
        visitedNodeIDs: inout Set<Node.ID>
    ) -> Location? {
        guard visitedNodeIDs.insert(nodeID).inserted,
              let node = nodes[nodeID]
        else { return nil }

        switch node.identity {
        case let .directory(path), let .file(path):
            return Location(path: path)

        case .repository:
            return nil

        case .logical:
            for edge in edges where edge.kind == .parsedFrom && edge.target == nodeID {
                if let location = location(for: edge.source, visitedNodeIDs: &visitedNodeIDs) {
                    return location
                }
            }
            return nil
        }
    }
}

extension SourceGraph {
    public struct Path: Hashable, Sendable, RawRepresentable, ExpressibleByStringLiteral {
        public var rawValue: String

        public init(rawValue: String) {
            self.rawValue = rawValue
        }

        public init(stringLiteral value: StringLiteralType) {
            self.rawValue = value
        }

        public func appending(_ path: Path) -> Path {
            guard !rawValue.isEmpty else { return path }
            guard !path.rawValue.isEmpty else { return self }
            return Path(rawValue: "\(rawValue)/\(path.rawValue)")
        }
    }
}

extension SourceGraph {
    public struct Location: Hashable, Sendable {
        public var path: Path
        public var span: Span?

        public init(path: Path, span: Span? = nil) {
            self.path = path
            self.span = span
        }
    }
}

extension SourceGraph.Location {
    public struct Position: Hashable, Sendable {
        public var line: Int
        public var column: Int

        public init(line: Int, column: Int) {
            self.line = line
            self.column = column
        }
    }

    public struct Span: Hashable, Sendable {
        public var start: Position
        public var end: Position?

        public init(start: Position, end: Position? = nil) {
            self.start = start
            self.end = end
        }
    }
}

extension SourceGraph {
    public struct Node: Equatable, Sendable, Identifiable {
        public var id: ID
        public var kind: Kind
        public var identity: Identity

        public init(identity: Identity) {
            self.id = ID(identity)
            self.kind = Kind(identity)
            self.identity = identity
        }
    }
}

extension SourceGraph.Node {
    public struct ID: Hashable, Sendable, RawRepresentable {
        public var rawValue: String

        public init(rawValue: String) {
            self.rawValue = rawValue
        }

        public init(_ identity: Identity) {
            self.rawValue = identity.rawValue
        }
    }

    public enum Kind: Equatable, Sendable {
        case repository
        case directory(Directory)
        case file(File)
        case logical(Logical)

        init(_ identity: Identity) {
            switch identity {
            case .repository:
                self = .repository
            case let .directory(path):
                self = .directory(.init(path: path))
            case let .file(path):
                self = .file(.init(path: path))
            case let .logical(kind, key):
                self = .logical(.init(kind: kind, key: key))
            }
        }
    }

    public enum Identity: Hashable, Sendable {
        case repository
        case directory(SourceGraph.Path)
        case file(SourceGraph.Path)
        case logical(kind: Logical.KindName, key: Logical.Key?)

        var rawValue: String {
            switch self {
            case .repository:
                "repository"
            case let .directory(path):
                "directory:\(path.rawValue)"
            case let .file(path):
                "file:\(path.rawValue)"
            case let .logical(kind, key):
                "logical:\(kind.rawValue):\(key?.rawValue ?? "_")"
            }
        }

        func prefixingPath(with prefix: SourceGraph.Path) -> Self {
            switch self {
            case .repository, .logical:
                self
            case let .directory(path):
                .directory(prefix.appending(path))
            case let .file(path):
                .file(prefix.appending(path))
            }
        }
    }

    public struct Directory: Equatable, Sendable {
        public var path: SourceGraph.Path
    }

    public struct File: Equatable, Sendable {
        public var path: SourceGraph.Path
    }

    public struct Logical: Equatable, Sendable {
        public var kind: KindName
        public var key: Key?
    }
}

extension SourceGraph.Node.Logical {
    public struct KindName: Hashable, Sendable, RawRepresentable, ExpressibleByStringLiteral {
        public var rawValue: String

        public init(rawValue: String) {
            self.rawValue = rawValue
        }

        public init(stringLiteral value: StringLiteralType) {
            self.rawValue = value
        }
    }

    public struct Key: Hashable, Sendable, RawRepresentable, ExpressibleByStringLiteral {
        public var rawValue: String

        public init(rawValue: String) {
            self.rawValue = rawValue
        }

        public init(stringLiteral value: StringLiteralType) {
            self.rawValue = value
        }
    }
}

extension SourceGraph {
    public struct Edge: Hashable, Sendable {
        public var source: Node.ID
        public var target: Node.ID
        public var kind: Kind
    }
}

extension SourceGraph.Edge {
    public enum Kind: Hashable, Sendable {
        case contains
        case parsedFrom
        case references
    }
}
