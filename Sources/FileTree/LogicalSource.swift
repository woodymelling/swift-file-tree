import Foundation

public struct LogicalSource<Value: Sendable>: Sendable {
    public var value: Value
    public var handle: SourceGraph.Handle

    public init(value: Value, handle: SourceGraph.Handle) {
        self.value = value
        self.handle = handle
    }
}

extension LogicalSource: Equatable where Value: Equatable {}

public protocol FileTreeCodec<Value>: Sendable {
    associatedtype Value: Sendable

    func decode(_ data: Data) throws -> Value
}

extension SourceGraph {
    public struct Handle: Hashable, Sendable {
        public var nodeID: Node.ID
        public var path: FieldPath?

        public init(nodeID: Node.ID, path: FieldPath? = nil) {
            self.nodeID = nodeID
            self.path = path
        }
    }
}

extension SourceGraph.Handle {
    public func field(_ components: String...) -> Self {
        var copy = self
        copy.path = (copy.path ?? []).appending(components)
        return copy
    }
}

extension SourceGraph {
    public struct FieldPath: Hashable, Sendable, ExpressibleByArrayLiteral {
        public var components: [String]

        public init(components: [String] = []) {
            self.components = components
        }

        public init(arrayLiteral elements: String...) {
            self.components = elements
        }

        public func appending(_ components: [String]) -> Self {
            .init(components: self.components + components)
        }
    }
}
