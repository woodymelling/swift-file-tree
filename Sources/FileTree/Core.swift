import Foundation
import UniformTypeIdentifiers
import IssueReporting

// MARK: Protocol
public protocol FileTreeComponent<Content> {
    associatedtype Content 

    associatedtype Body

    func read(from url: URL) throws -> Content

    func write(_ data: Content, to url: URL) throws

    @FileTreeBuilder
    var body: Body { get }
}

extension FileTreeComponent where Body == Never {
    public var body: Body {
        return fatalError("Body of \(Self.self) should never be called")
    }
}

extension FileTreeComponent where Body: FileTreeComponent, Body.Content == Content {
    public func read(from url: URL) throws -> Content {
        try body.read(from: url)
    }

    public func write(_ data: Content, to url: URL) throws {
        try body.write(data, to: url)
    }
}


// MARK: Result Builder
@resultBuilder
public struct FileTreeBuilder {
    public static func buildExpression<Component>(_ component: Component) -> Component where Component: FileTreeComponent {
        component
    }

    public static func buildBlock<Component>(_ component: Component) -> Component where Component: FileTreeComponent {
        component
    }

    public static func buildBlock<each Component>(_ component: repeat each Component) -> TupleFileSystemComponent<repeat each Component> where repeat each Component: FileTreeComponent {
        return TupleFileSystemComponent(repeat each component)
    }
}

public struct FileTree<Component: FileTreeComponent>: FileTreeComponent {

    public var component: Component
    public typealias Content = Component.Content

    public init(@FileTreeBuilder component: () -> Component) {
        self.component = component()
    }

    public func read(from url: URL) throws -> Component.Content {
        try self.component.read(from: url)
    }

    public func write(_ data: Component.Content, to url: URL) throws {
        try self.component.write(data, to: url)
    }
}
