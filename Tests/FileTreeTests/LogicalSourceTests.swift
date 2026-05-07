import Foundation
@testable import FileTree
import Testing

struct LogicalSourceTests {
    @Test func decodeReturnsLogicalSourceWithPlainValueAndHandle() throws {
        let directory = try LogicalSourceTemporaryDirectory()
        try Data("wicked-woods|Wicked Woods".utf8)
            .write(to: directory.url.appendingPathComponent("event", withType: "txt"))

        let result = try File("event", "txt")
            .decode(PipeSeparatedEventCodec.EventSource.self, as: "ome.event", using: PipeSeparatedEventCodec())
            .read(from: directory.url)

        let source = try result.output.requiredValue

        #expect(source.value == PipeSeparatedEventCodec.EventSource(id: "wicked-woods", name: "Wicked Woods"))
        #expect(source.handle.nodeID == SourceGraph.Node.ID(.logical(kind: "ome.event", key: "wicked-woods")))
    }

    @Test func identifiableDecodeUsesIDAsLogicalKey() throws {
        let directory = try LogicalSourceTemporaryDirectory()
        try Data("wicked-woods|Wicked Woods".utf8)
            .write(to: directory.url.appendingPathComponent("event", withType: "txt"))

        let result = try File("event", "txt")
            .decode(PipeSeparatedEventCodec.EventSource.self, as: "ome.event", using: PipeSeparatedEventCodec())
            .read(from: directory.url)

        #expect(result.graph.containsNode(.logical(kind: "ome.event", key: "wicked-woods")))
    }

    @Test func decodeAddsLogicalNodeAndParsedFromEdge() throws {
        let directory = try LogicalSourceTemporaryDirectory()
        try Data("wicked-woods|Wicked Woods".utf8)
            .write(to: directory.url.appendingPathComponent("event", withType: "txt"))

        let result = try File("event", "txt")
            .decode(PipeSeparatedEventCodec.EventSource.self, as: "ome.event", using: PipeSeparatedEventCodec())
            .read(from: directory.url)

        #expect(
            result.graph.containsEdge(
                from: .file("event.txt"),
                to: .logical(kind: "ome.event", key: "wicked-woods"),
                kind: .parsedFrom
            )
        )
    }

    @Test func decodeFailureReturnsDiagnosticAndInvalidOutput() throws {
        let directory = try LogicalSourceTemporaryDirectory()
        try Data("not-valid".utf8)
            .write(to: directory.url.appendingPathComponent("event", withType: "txt"))

        let result = try File("event", "txt")
            .decode(PipeSeparatedEventCodec.EventSource.self, as: "ome.event", using: PipeSeparatedEventCodec())
            .read(from: directory.url)

        #expect(result.output.isInvalid)
        #expect(result.diagnostics.hasErrors)
        #expect(result.diagnostics.diagnostics.map(\.code.rawValue) == ["file-tree.decode.failed"])
    }

    @Test func decodeFailureDiagnosticIncludesFileLocation() throws {
        let directory = try LogicalSourceTemporaryDirectory()
        try Data("not-valid".utf8)
            .write(to: directory.url.appendingPathComponent("event", withType: "txt"))

        let result = try File("event", "txt")
            .decode(PipeSeparatedEventCodec.EventSource.self, as: "ome.event", using: PipeSeparatedEventCodec())
            .read(from: directory.url)

        #expect(
            result.diagnostics.diagnostics.first?.location?.sourceLocation
            == .init(path: "event.txt")
        )
    }
}

private struct PipeSeparatedEventCodec: FileTreeCodec {
    func decode(_ data: Data) throws -> EventSource {
        let string = String(decoding: data, as: UTF8.self)
        let parts = string.split(separator: "|", omittingEmptySubsequences: false)
        guard parts.count == 2 else { throw InvalidInput() }
        return EventSource(id: String(parts[0]), name: String(parts[1]))
    }

    struct EventSource: Equatable, Identifiable, Sendable {
        var id: String
        var name: String
    }

    struct InvalidInput: Error {}
}

private final class LogicalSourceTemporaryDirectory {
    let url: URL

    init() throws {
        self.url = FileManager.default.temporaryDirectory
            .appending(component: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: self.url, withIntermediateDirectories: true)
    }

    deinit {
        try? FileManager.default.removeItem(at: self.url)
    }
}
