import Foundation

public struct PairFileSystemComponent<First: FileTreeReader, Second: FileTreeReader>: FileTreeReader {
    public var first: First
    public var second: Second

    @inlinable public init(_ first: First, _ second: Second) {
        self.first = first
        self.second = second
    }

    public typealias Content = (First.Content, Second.Content)

    public func read(from url: URL) throws -> FileTreeResult<Content> {
        let firstResult = try first.read(from: url)
        let secondResult = try second.read(from: url)
        var diagnostics = DiagnosticReport<FileTreeLocation>()
        diagnostics.append(contentsOf: firstResult.diagnostics)
        diagnostics.append(contentsOf: secondResult.diagnostics)
        var graph = SourceGraph()
        graph.append(firstResult.graph)
        graph.append(secondResult.graph)

        switch (firstResult.output, secondResult.output) {
        case let (.value(firstOutput), .value(secondOutput)):
            return .value((firstOutput, secondOutput), graph: graph, diagnostics: diagnostics)
        case (.value, .invalid), (.invalid, .value), (.invalid, .invalid):
            return .invalid(graph: graph, diagnostics: diagnostics)
        }
    }
}

extension PairFileSystemComponent: FileTreeWriter where First: FileTreeWriter, Second: FileTreeWriter {
    public func write(_ content: Content, to url: URL) throws -> FileTreeResult<Content> {
        let firstResult = try first.write(content.0, to: url)
        let secondResult = try second.write(content.1, to: url)
        return results(firstResult, secondResult)
    }

    public func write(
        _ content: Content,
        to url: URL,
        context: FileTreeWriteContext
    ) throws -> FileTreeResult<Content> {
        let firstResult = try first.write(content.0, to: url, context: context)
        let secondResult = try second.write(content.1, to: url, context: context)
        return results(firstResult, secondResult)
    }

    private func results(
        _ firstResult: FileTreeResult<First.Content>,
        _ secondResult: FileTreeResult<Second.Content>
    ) -> FileTreeResult<Content> {
        var diagnostics = DiagnosticReport<FileTreeLocation>()
        diagnostics.append(contentsOf: firstResult.diagnostics)
        diagnostics.append(contentsOf: secondResult.diagnostics)
        var graph = SourceGraph()
        graph.append(firstResult.graph)
        graph.append(secondResult.graph)

        switch (firstResult.output, secondResult.output) {
        case let (.value(firstOutput), .value(secondOutput)) where !diagnostics.hasErrors:
            return .value((firstOutput, secondOutput), graph: graph, diagnostics: diagnostics)
        case (.value, .value), (.value, .invalid), (.invalid, .value), (.invalid, .invalid):
            return .invalid(graph: graph, diagnostics: diagnostics)
        }
    }
}
