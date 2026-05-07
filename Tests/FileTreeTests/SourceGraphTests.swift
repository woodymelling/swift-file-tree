import Foundation
@testable import FileTree
import Testing

struct SourceGraphTests {
    @Test func fileReadCapturesFileNode() throws {
        let directory = try GraphTemporaryDirectory()
        try Data("Hello".utf8).write(to: directory.url.appendingPathComponent("Greeting", withType: "txt"))

        let result = try File("Greeting", "txt").read(from: directory.url)

        #expect(result.graph.containsNode(.file("Greeting.txt")))
    }

    @Test func directoryReadCapturesDirectoryAndChildFileNodes() throws {
        let directory = try GraphTemporaryDirectory()
        let blogURL = directory.url.appending(component: "Blog", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: blogURL, withIntermediateDirectories: true)
        try Data("About".utf8).write(to: blogURL.appendingPathComponent("About", withType: "txt"))

        let result = try Directory("Blog") {
            File("About", "txt")
        }
        .read(from: directory.url)

        #expect(result.graph.containsNode(.directory("Blog")))
        #expect(result.graph.containsNode(.file("Blog/About.txt")))
        #expect(result.graph.containsEdge(from: .directory("Blog"), to: .file("Blog/About.txt"), kind: .contains))
    }

    @Test func manyFilesReadCapturesEachFileNode() throws {
        let directory = try GraphTemporaryDirectory()
        try Data("One".utf8).write(to: directory.url.appendingPathComponent("One", withType: "txt"))
        try Data("Two".utf8).write(to: directory.url.appendingPathComponent("Two", withType: "txt"))

        let result = try File.Many(withExtension: "txt").read(from: directory.url)

        #expect(result.graph.containsNode(.file("One.txt")))
        #expect(result.graph.containsNode(.file("Two.txt")))
    }
}

private final class GraphTemporaryDirectory {
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
