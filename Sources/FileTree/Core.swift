import Foundation

// MARK: Protocol
public protocol FileTreeReader<Content> {
    associatedtype Content: Sendable

    associatedtype Body

    func read(from url: URL) throws -> FileTreeResult<Content>

    // func write(_ data: Content, to url: URL) throws

    @FileTreeBuilder
    var body: Body { get }

}

// MARK: Protocol
public protocol FileTreeWriter<Content>: FileTreeReader {
    func write(_ content: Content, to url: URL) throws -> FileTreeResult<Content>
    func write(
        _ content: Content,
        to url: URL,
        context: FileTreeWriteContext
    ) throws -> FileTreeResult<Content>
}

struct ErrorAtURL: Error {
    let url: URL
    let underlyingError: Error
}

extension FileTreeReader where Body == Never {
    public var body: Body {
        return fatalError("Body of \(Self.self) should never be called")
    }
}

extension FileTreeReader where Body: FileTreeReader, Body.Content == Content {
    public func read(from url: URL) throws -> FileTreeResult<Content> {
        do {
            return try body.read(from: url)
        } catch {
            if let error = error as? ErrorAtURL {
                throw error
            }

            throw ErrorAtURL(url: url, underlyingError: error)
        }
    }

    // public func write(_ data: Content, to url: URL) throws {
    //     try body.write(data, to: url)
    // }
}

extension FileTreeWriter where Body: FileTreeWriter, Body.Content == Content {
    public func write(_ content: Content, to url: URL) throws -> FileTreeResult<Content> {
        try body.write(content, to: url)
    }

    public func write(
        _ content: Content,
        to url: URL,
        context: FileTreeWriteContext
    ) throws -> FileTreeResult<Content> {
        try body.write(content, to: url, context: context)
    }
}

extension FileTreeWriter {
    public func write(
        _ content: Content,
        to url: URL,
        context: FileTreeWriteContext
    ) throws -> FileTreeResult<Content> {
        try write(content, to: url)
    }

    public func rewrite(_ content: Content, at url: URL) throws -> FileTreeResult<Content> {
        let sourceResult = try read(from: url)
        return try write(
            content,
            to: url,
            context: FileTreeWriteContext(sourceURL: url, graph: sourceResult.graph)
        )
    }
}

// MARK: Result Builder
@resultBuilder
public struct FileTreeBuilder {
    public static func buildExpression<Component>(_ component: Component) -> Component
    where Component: FileTreeReader {
        component
    }

    public static func buildBlock<Component>(_ component: Component) -> Component
    where Component: FileTreeReader {
        component
    }

    public static func buildBlock<First, Second>(
        _ first: First,
        _ second: Second
    ) -> PairFileSystemComponent<First, Second>
    where First: FileTreeReader, Second: FileTreeReader {
        PairFileSystemComponent(first, second)
    }

    public static func buildBlock<each Component>(
        _ component: repeat each Component
    ) -> TupleFileSystemComponent<repeat each Component>
    where repeat each Component: FileTreeReader {
        TupleFileSystemComponent(repeat each component)
    }

//    public static func buildPartialBlock<F: FileTreeReader>(first content: F) -> F {
//        content
//    }
//
//    public static func buildPartialBlock<F0, F1>(accumulated: F0, next: F1)
//        -> PairFileTreeReader<F0, F1> where F0: FileTreeReader, F1: FileTreeReader
//    {
//        return PairFileTreeReader((accumulated, next))
//    }
}

public struct FileTree<Component: FileTreeReader>: FileTreeReader {

    public var component: Component
    public typealias Content = Component.Content

    public init(@FileTreeBuilder component: () -> Component) {
        self.component = component()
    }

    public func read(from url: URL) throws -> FileTreeResult<Component.Content> {
        try self.component.read(from: url)
    }

    // public func write(_ data: Component.Content, to url: URL) throws {
    //     try self.component.write(data, to: url)
    // }
}

extension FileTree: FileTreeWriter where Component: FileTreeWriter {
    public func write(_ content: Component.Content, to url: URL) throws -> FileTreeResult<Component.Content> {
        try self.component.write(content, to: url)
    }

    public func write(
        _ content: Component.Content,
        to url: URL,
        context: FileTreeWriteContext
    ) throws -> FileTreeResult<Component.Content> {
        try self.component.write(content, to: url, context: context)
    }
}
