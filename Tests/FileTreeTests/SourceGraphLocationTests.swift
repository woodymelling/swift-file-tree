import Foundation
@testable import FileTree
import Testing

struct SourceGraphLocationTests {
    @Test func logicalSourceHandleCanCreateFieldHandle() throws {
        let handle = SourceGraph.Handle(nodeID: .init(rawValue: "logical:ome.event:wicked-woods"))

        let fieldHandle = handle.field("location", "address")

        #expect(fieldHandle.nodeID == handle.nodeID)
        #expect(fieldHandle.path?.components == ["location", "address"])
    }

    @Test func graphResolvesLogicalHandleToSourceFileLocation() throws {
        let directory = try LocationTemporaryDirectory()
        try Data("wicked-woods|Wicked Woods".utf8)
            .write(to: directory.url.appendingPathComponent("event", withType: "txt"))

        let result = try File("event", "txt")
            .decode(LocationEventCodec.EventSource.self, as: "ome.event", using: LocationEventCodec())
            .read(from: directory.url)

        let source = try result.output.requiredValue

        #expect(result.graph.location(for: source.handle) == .init(path: "event.txt"))
    }

    @Test func graphResolvesFieldHandleToSourceFileLocationFallback() throws {
        let directory = try LocationTemporaryDirectory()
        try Data("wicked-woods|Wicked Woods".utf8)
            .write(to: directory.url.appendingPathComponent("event", withType: "txt"))

        let result = try File("event", "txt")
            .decode(LocationEventCodec.EventSource.self, as: "ome.event", using: LocationEventCodec())
            .read(from: directory.url)

        let source = try result.output.requiredValue

        #expect(result.graph.location(for: source.handle.field("name")) == .init(path: "event.txt"))
    }

    @Test func fieldPathAppendsNestedComponents() {
        let path = SourceGraph.FieldPath(components: ["location"])

        #expect(path.appending(["coordinates", "latitude"]).components == ["location", "coordinates", "latitude"])
    }
}

private struct LocationEventCodec: FileTreeCodec {
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

private final class LocationTemporaryDirectory {
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
