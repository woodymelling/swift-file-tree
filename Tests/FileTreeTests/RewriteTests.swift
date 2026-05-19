import Foundation
@testable import FileTree
import Testing

struct RewriteTests {
    @Test func rewritePassesExistingFileDataToConvertedWriter() throws {
        let directory = try RewriteTemporaryDirectory()
        try Data("name: Old\n# keep\n".utf8)
            .write(to: directory.url.appendingPathComponent("event", withType: "txt"))

        let tree = File("event", "txt")
            .convert(RewriteNameConversion())

        let result = try tree.rewrite("New", at: directory.url)

        #expect(try result.output.requiredValue == "New")
        #expect(
            try directory.text(at: "event.txt")
            == "name: New\n# keep\n"
        )
    }

    @Test func tupleRewritePassesSourceContextToEachChildFile() throws {
        let directory = try RewriteTemporaryDirectory()
        try Data("name: Old Event\n# event comment\n".utf8)
            .write(to: directory.url.appendingPathComponent("event", withType: "txt"))
        try Data("name: Old Venue\n# venue comment\n".utf8)
            .write(to: directory.url.appendingPathComponent("venue", withType: "txt"))

        let tree = FileTree {
            File("event", "txt")
                .convert(RewriteNameConversion())
            File("venue", "txt")
                .convert(RewriteNameConversion())
        }

        let result = try tree.rewrite(("New Event", "New Venue"), at: directory.url)

        let output = try result.output.requiredValue
        #expect(output.0 == "New Event")
        #expect(output.1 == "New Venue")
        #expect(
            try directory.text(at: "event.txt")
            == "name: New Event\n# event comment\n"
        )
        #expect(
            try directory.text(at: "venue.txt")
            == "name: New Venue\n# venue comment\n"
        )
    }

    @Test func fileManyMapRewritePassesPerFileSourceContext() throws {
        let directory = try RewriteTemporaryDirectory()
        try Data("name: Old A\n# a comment\n".utf8)
            .write(to: directory.url.appendingPathComponent("a", withType: "txt"))
        try Data("name: Old B\n# b comment\n".utf8)
            .write(to: directory.url.appendingPathComponent("b", withType: "txt"))

        let tree = File.Many(withExtension: "txt")
            .map(FileContentConversion(RewriteNameConversion()))

        let result = try tree.rewrite(
            [
                FileContent(fileName: "a", fileType: "txt", data: "New A"),
                FileContent(fileName: "b", fileType: "txt", data: "New B"),
            ],
            at: directory.url
        )

        #expect(try result.output.requiredValue.map(\.data) == ["New A", "New B"])
        #expect(
            try directory.text(at: "a.txt")
            == "name: New A\n# a comment\n"
        )
        #expect(
            try directory.text(at: "b.txt")
            == "name: New B\n# b comment\n"
        )
    }

    @Test func directoryRewriteDescendsIntoSourceURL() throws {
        let directory = try RewriteTemporaryDirectory()
        let sourceURL = directory.url.appending(component: "source")
        try FileManager.default.createDirectory(at: sourceURL, withIntermediateDirectories: true)
        try Data("name: Old\n# source comment\n".utf8)
            .write(to: sourceURL.appendingPathComponent("event", withType: "txt"))

        let tree = Directory("source") {
            File("event", "txt")
                .convert(RewriteNameConversion())
        }

        let result = try tree.rewrite("New", at: directory.url)

        #expect(try result.output.requiredValue == "New")
        #expect(
            try directory.text(at: "source/event.txt")
            == "name: New\n# source comment\n"
        )
    }

    @Test func optionalDirectoryRewriteDescendsIntoSourceURL() throws {
        let directory = try RewriteTemporaryDirectory()
        let stagesURL = directory.url.appending(component: "stages")
        try FileManager.default.createDirectory(at: stagesURL, withIntermediateDirectories: true)
        try Data("name: Old Meadow\n# stage comment\n".utf8)
            .write(to: stagesURL.appendingPathComponent("meadow", withType: "txt"))

        let tree = Directory.Optional("stages") {
            File("meadow", "txt")
                .convert(RewriteNameConversion())
        }

        let result = try tree.rewrite("New Meadow", at: directory.url)

        #expect(try result.output.requiredValue == "New Meadow")
        #expect(
            try directory.text(at: "stages/meadow.txt")
            == "name: New Meadow\n# stage comment\n"
        )
    }

    @Test func writeWithoutSourceContextUsesCanonicalOutput() throws {
        let directory = try RewriteTemporaryDirectory()
        let tree = File("event", "txt")
            .convert(RewriteNameConversion())

        let result = try tree.write("New", to: directory.url)

        #expect(try result.output.requiredValue == "New")
        #expect(try directory.text(at: "event.txt") == "name: New\n")
    }
}

private struct RewriteNameConversion: Conversion {
    func apply(_ input: Data) throws -> String {
        let text = String(decoding: input, as: UTF8.self)
        return text
            .split(separator: "\n", omittingEmptySubsequences: false)
            .first
            .map { line in
                line.hasPrefix("name: ")
                    ? String(line.dropFirst("name: ".count))
                    : String(line)
            } ?? ""
    }

    func unapply(_ output: String) throws -> Data {
        canonicalData(for: output)
    }

    func unapply(_ output: String, in context: FileTreeWriteContext) -> Conversions.Result<Data> {
        do {
            guard let existing = try context.rootText() else {
                return .value(canonicalData(for: output))
            }

            var lines = existing.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
            guard !lines.isEmpty else {
                return .value(canonicalData(for: output))
            }

            if lines[0].hasPrefix("name:") {
                lines[0] = "name: \(output)"
            } else {
                lines.insert("name: \(output)", at: 0)
            }

            return .value(Data(lines.joined(separator: "\n").utf8))
        } catch {
            return .value(canonicalData(for: output))
        }
    }

    private func canonicalData(for output: String) -> Data {
        Data("name: \(output)\n".utf8)
    }
}

private final class RewriteTemporaryDirectory {
    let url: URL

    init() throws {
        self.url = FileManager.default.temporaryDirectory
            .appending(component: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: self.url, withIntermediateDirectories: true)
    }

    deinit {
        try? FileManager.default.removeItem(at: self.url)
    }

    func text(at path: String) throws -> String {
        try String(
            decoding: Data(contentsOf: url.appending(path: path)),
            as: UTF8.self
        )
    }
}
