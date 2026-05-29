import Foundation
@testable import FileTree
import Testing

struct TupleWriteTests {
    @Test func fileManyWritePrintsEachFileAndReturnsGraph() throws {
        let directory = try TupleWriteTemporaryDirectory()

        let result = try File.Many(withExtension: "txt")
            .write(
                [
                    FileContent(fileName: "event", fileType: nil, data: Data("Wicked Woods".utf8)),
                    FileContent(fileName: "venue", fileType: nil, data: Data("Meadow Stage".utf8)),
                ],
                to: directory.url
            )

        let event = try String(
            decoding: Data(contentsOf: directory.url.appendingPathComponent("event", withType: "txt")),
            as: UTF8.self
        )
        let venue = try String(
            decoding: Data(contentsOf: directory.url.appendingPathComponent("venue", withType: "txt")),
            as: UTF8.self
        )

        let output = try result.output.requiredValue
        #expect(output.count == 2)
        #expect(event == "Wicked Woods")
        #expect(venue == "Meadow Stage")
        #expect(result.graph.containsNode(.file("event.txt")))
        #expect(result.graph.containsNode(.file("venue.txt")))
    }

    @Test func tupleWritePrintsEachElementThroughMatchingChild() throws {
        let directory = try TupleWriteTemporaryDirectory()

        let tree = FileTree {
            File("event", "txt")
                .convert(TupleWriteTrimmingConversion())
            File("venue", "txt")
                .convert(TupleWriteTrimmingConversion())
        }

        let result = try tree.write(("  Wicked Woods  ", "  Meadow Stage  "), to: directory.url)

        let event = try String(
            decoding: Data(contentsOf: directory.url.appendingPathComponent("event", withType: "txt")),
            as: UTF8.self
        )
        let venue = try String(
            decoding: Data(contentsOf: directory.url.appendingPathComponent("venue", withType: "txt")),
            as: UTF8.self
        )

        let output = try result.output.requiredValue
        #expect(output.0 == "  Wicked Woods  ")
        #expect(output.1 == "  Meadow Stage  ")
        #expect(event == "Wicked Woods")
        #expect(venue == "Meadow Stage")
        #expect(result.graph.containsNode(.file("event.txt")))
        #expect(result.graph.containsNode(.file("venue.txt")))
    }

    @Test func tupleWriteMergesDiagnosticsFromChildren() throws {
        let directory = try TupleWriteTemporaryDirectory()

        let result = try TupleFileSystemComponent(
            File("event", "txt")
                .convert(TupleWriteWarningConversion(code: "ome.event.name.printed")),
            File("venue", "txt")
                .convert(TupleWriteWarningConversion(code: "ome.venue.name.printed"))
        )
        .write(("Wicked Woods", "Meadow Stage"), to: directory.url)

        let output = try result.output.requiredValue
        #expect(output.0 == "Wicked Woods")
        #expect(output.1 == "Meadow Stage")
        #expect(
            result.diagnostics.diagnostics.map(\.code.rawValue)
            == [
                "ome.event.name.printed",
                "ome.venue.name.printed",
            ]
        )
    }

    @Test func tupleReadHandlesMissingOptionalConvertedFile() throws {
        let directory = try TupleWriteTemporaryDirectory()
        try Data("Meadow Stage".utf8)
            .write(to: directory.url.appendingPathComponent("venue", withType: "txt"))

        let tree = FileTree {
            File.Optional("event", "txt")
                .convert(TupleWriteTrimmingConversion())
            File("venue", "txt")
                .convert(TupleWriteTrimmingConversion())
        }

        let output = try tree.read(from: directory.url).output.requiredValue

        #expect(output.0 == nil)
        #expect(output.1 == "Meadow Stage")
    }

    @Test func tupleReadHandlesMissingOptionalConvertedFileBeforeDirectoryMany() throws {
        let directory = try TupleWriteTemporaryDirectory()
        let eventsURL = directory.url.appending(component: "events")
        let eventURL = eventsURL.appending(component: "wicked-woods")
        try FileManager.default.createDirectory(at: eventURL, withIntermediateDirectories: true)
        try Data("Wicked Woods".utf8)
            .write(to: eventURL.appendingPathComponent("event", withType: "txt"))

        let tree = FileTree {
            File.Optional("calendar", "txt")
                .convert(TupleWriteTrimmingConversion())
            Directory("events") {
                Directory.Many {
                    File("event", "txt")
                        .convert(TupleWriteTrimmingConversion())
                }
            }
        }

        let output = try tree.read(from: directory.url).output.requiredValue

        #expect(output.0 == nil)
        #expect(output.1.map(\.directoryName) == ["wicked-woods"])
        #expect(output.1.map(\.components) == ["Wicked Woods"])
    }

    @Test func convertedTupleReadHandlesMissingOptionalConvertedFileBeforeDirectoryMany() throws {
        let directory = try TupleWriteTemporaryDirectory()
        let eventsURL = directory.url.appending(component: "events")
        let eventURL = eventsURL.appending(component: "wicked-woods")
        try FileManager.default.createDirectory(at: eventURL, withIntermediateDirectories: true)
        try Data("Wicked Woods".utf8)
            .write(to: eventURL.appendingPathComponent("event", withType: "txt"))

        let tree = FileTree {
            File.Optional("calendar", "txt")
                .convert(TupleWriteTrimmingConversion())
            Directory("events") {
                Directory.Many {
                    File("event", "txt")
                        .convert(TupleWriteTrimmingConversion())
                }
            }
        }
        .convert(TupleWriteRepositoryConversion())

        let output = try tree.read(from: directory.url).output.requiredValue

        #expect(output.calendar == nil)
        #expect(output.events.map(\.directoryName) == ["wicked-woods"])
        #expect(output.events.map(\.components) == ["Wicked Woods"])
    }

    @Test func nestedWriterReadHandlesMissingOptionalConvertedFileBeforeDirectoryMany() throws {
        let directory = try TupleWriteTemporaryDirectory()
        let eventsURL = directory.url.appending(component: "events")
        let eventURL = eventsURL.appending(component: "wicked-woods")
        try FileManager.default.createDirectory(at: eventURL, withIntermediateDirectories: true)
        try Data("Wicked Woods".utf8)
            .write(to: eventURL.appendingPathComponent("event", withType: "txt"))

        let output = try TupleWriteRepositoryFileTree()
            .read(from: directory.url)
            .output
            .requiredValue

        #expect(output.calendar == nil)
        #expect(output.events.map(\.directoryName) == ["wicked-woods"])
        #expect(output.events.map(\.components.event) == ["Wicked Woods"])
        #expect(output.events.map(\.components.stages) == [nil])
        #expect(output.events.map(\.components.participants) == [nil])
    }

    @Test func directoryTupleWritePrefixesGraphAndWritesInsideDirectory() throws {
        let directory = try TupleWriteTemporaryDirectory()

        let tree = Directory("source") {
            File("event", "txt")
                .convert(TupleWriteTrimmingConversion())
            File("venue", "txt")
                .convert(TupleWriteTrimmingConversion())
        }

        let result = try tree.write(("  Wicked Woods  ", "  Meadow Stage  "), to: directory.url)

        let event = try String(
            decoding: Data(
                contentsOf: directory.url
                    .appending(component: "source")
                    .appendingPathComponent("event", withType: "txt")
            ),
            as: UTF8.self
        )
        let venue = try String(
            decoding: Data(
                contentsOf: directory.url
                    .appending(component: "source")
                    .appendingPathComponent("venue", withType: "txt")
            ),
            as: UTF8.self
        )

        #expect(event == "Wicked Woods")
        #expect(venue == "Meadow Stage")
        #expect(result.graph.containsNode(.directory("source")))
        #expect(result.graph.containsNode(.file("source/event.txt")))
        #expect(result.graph.containsNode(.file("source/venue.txt")))
        #expect(result.graph.containsEdge(from: .directory("source"), to: .file("source/event.txt"), kind: .contains))
        #expect(result.graph.containsEdge(from: .directory("source"), to: .file("source/venue.txt"), kind: .contains))
    }

    @Test func directoryManyTupleWritePrintsEachDirectory() throws {
        let directory = try TupleWriteTemporaryDirectory()

        let tree = Directory.Many {
            File("event", "txt")
                .convert(TupleWriteTrimmingConversion())
            File("venue", "txt")
                .convert(TupleWriteTrimmingConversion())
        }

        let result = try tree.write(
            [
                DirectoryContent(
                    directoryName: "wicked-woods",
                    components: ("  Wicked Woods  ", "  Meadow Stage  ")
                ),
                DirectoryContent(
                    directoryName: "winter-market",
                    components: ("  Winter Market  ", "  Town Hall  ")
                ),
            ],
            to: directory.url
        )

        let wickedWoods = try String(
            decoding: Data(
                contentsOf: directory.url
                    .appending(component: "wicked-woods")
                    .appendingPathComponent("event", withType: "txt")
            ),
            as: UTF8.self
        )
        let townHall = try String(
            decoding: Data(
                contentsOf: directory.url
                    .appending(component: "winter-market")
                    .appendingPathComponent("venue", withType: "txt")
            ),
            as: UTF8.self
        )

        let output = try result.output.requiredValue
        #expect(output.count == 2)
        #expect(wickedWoods == "Wicked Woods")
        #expect(townHall == "Town Hall")
        #expect(result.graph.containsNode(.directory("wicked-woods")))
        #expect(result.graph.containsNode(.file("wicked-woods/event.txt")))
        #expect(result.graph.containsNode(.file("winter-market/venue.txt")))
    }

    @Test func optionalFileWriteWritesPresentData() throws {
        let directory = try TupleWriteTemporaryDirectory()

        let result = try File.Optional("event", "txt")
            .write(Data("Wicked Woods".utf8), to: directory.url)

        let event = try String(
            decoding: Data(contentsOf: directory.url.appendingPathComponent("event", withType: "txt")),
            as: UTF8.self
        )

        let output = try result.output.requiredValue
        #expect(output == Data("Wicked Woods".utf8))
        #expect(event == "Wicked Woods")
        #expect(result.graph.containsNode(.file("event.txt")))
    }

    @Test func optionalFileWriteSkipsNilFile() throws {
        let directory = try TupleWriteTemporaryDirectory()
        try Data("Existing".utf8)
            .write(to: directory.url.appendingPathComponent("event", withType: "txt"))

        let result = try File.Optional("event", "txt")
            .write(nil, to: directory.url)

        let output = try result.output.requiredValue
        let event = try String(
            decoding: Data(contentsOf: directory.url.appendingPathComponent("event", withType: "txt")),
            as: UTF8.self
        )
        #expect(output == nil)
        #expect(event == "Existing")
        #expect(result.graph.nodes.isEmpty)
    }

    @Test func optionalFileWriteDeletesNilFileWhenEnabled() throws {
        let directory = try TupleWriteTemporaryDirectory()
        try Data("Existing".utf8)
            .write(to: directory.url.appendingPathComponent("event", withType: "txt"))

        let result = try $deletingNilOptionalWrites.withValue(true) {
            try File.Optional("event", "txt")
                .write(nil, to: directory.url)
        }

        let output = try result.output.requiredValue
        #expect(output == nil)
        #expect(!FileManager.default.fileExists(atPath: directory.url.appendingPathComponent("event", withType: "txt").path()))
        #expect(result.graph.nodes.isEmpty)
    }

    @Test func optionalDirectoryWriteSkipsNilDirectory() throws {
        let directory = try TupleWriteTemporaryDirectory()
        let stagesURL = directory.url.appending(component: "stages")
        try FileManager.default.createDirectory(at: stagesURL, withIntermediateDirectories: true)
        try Data("Existing".utf8)
            .write(to: stagesURL.appendingPathComponent("meadow", withType: "txt"))

        let result = try Directory.Optional("stages") {
            File.Many(withExtension: "txt")
        }
        .write(nil, to: directory.url)

        let output = try result.output.requiredValue
        #expect(output == nil)
        #expect(FileManager.default.fileExists(atPath: stagesURL.appendingPathComponent("meadow", withType: "txt").path()))
    }

    @Test func optionalDirectoryWriteDeletesNilDirectoryWhenEnabled() throws {
        let directory = try TupleWriteTemporaryDirectory()
        let stagesURL = directory.url.appending(component: "stages")
        try FileManager.default.createDirectory(at: stagesURL, withIntermediateDirectories: true)
        try Data("Existing".utf8)
            .write(to: stagesURL.appendingPathComponent("meadow", withType: "txt"))

        let result = try $deletingNilOptionalWrites.withValue(true) {
            try Directory.Optional("stages") {
                File.Many(withExtension: "txt")
            }
            .write(nil, to: directory.url)
        }

        let output = try result.output.requiredValue
        #expect(output == nil)
        #expect(!FileManager.default.fileExists(atPath: stagesURL.path()))
    }

    @Test func optionalDirectoryWritePrefixesGraphAndWritesPresentContent() throws {
        let directory = try TupleWriteTemporaryDirectory()

        let result = try Directory.Optional("stages") {
            File.Many(withExtension: "txt")
        }
        .write(
            [
                FileContent(fileName: "meadow", fileType: nil, data: Data("Meadow".utf8)),
            ],
            to: directory.url
        )

        let meadow = try String(
            decoding: Data(
                contentsOf: directory.url
                    .appending(component: "stages")
                    .appendingPathComponent("meadow", withType: "txt")
            ),
            as: UTF8.self
        )

        let optionalOutput = try result.output.requiredValue
        let output = try #require(optionalOutput)
        #expect(output.count == 1)
        #expect(meadow == "Meadow")
        #expect(result.graph.containsNode(.directory("stages")))
        #expect(result.graph.containsNode(.file("stages/meadow.txt")))
        #expect(result.graph.containsEdge(from: .directory("stages"), to: .file("stages/meadow.txt"), kind: .contains))
    }
}

private struct TupleWriteTrimmingConversion: Conversion {
    func apply(_ input: Data) throws -> String {
        String(decoding: input, as: UTF8.self)
    }

    func unapply(_ output: String) throws -> Data {
        Data(output.utf8)
    }

    func unapply(_ output: String, in graph: SourceGraph) -> Conversions.Result<Data> {
        .value(Data(output.trimmingCharacters(in: .whitespacesAndNewlines).utf8))
    }
}

private struct TupleWriteWarningConversion: Conversion {
    var code: Diagnostic.Code

    func apply(_ input: Data) throws -> String {
        String(decoding: input, as: UTF8.self)
    }

    func unapply(_ output: String) throws -> Data {
        Data(output.utf8)
    }

    func unapply(_ output: String, in graph: SourceGraph) -> Conversions.Result<Data> {
        .value(
            Data(output.utf8),
            diagnostics: .init(
                diagnostics: [
                    .init(
                        severity: .warning,
                        code: code,
                        message: "Printed with warning"
                    )
                ]
            )
        )
    }
}

private struct TupleWriteRepository: Equatable {
    var calendar: String?
    var events: [DirectoryContent<String>]
}

private struct TupleWriteRepositoryConversion: Conversion {
    func apply(_ input: (String?, [DirectoryContent<String>])) throws -> TupleWriteRepository {
        TupleWriteRepository(calendar: input.0, events: input.1)
    }

    func unapply(_ output: TupleWriteRepository) throws -> (String?, [DirectoryContent<String>]) {
        (output.calendar, output.events)
    }
}

private struct TupleWriteRepositoryFileTree: FileTreeWriter {
    var body: some FileTreeWriter<TupleWriteNestedRepository> {
        FileTree {
            File.Optional("calendar", "txt")
                .convert(TupleWriteCalendarConversion())

            Directory("events") {
                Directory.Many {
                    TupleWriteEventFileTree()
                }
            }
        }
        .convert(TupleWriteNestedRepositoryConversion())
    }
}

private struct TupleWriteEventFileTree: FileTreeWriter {
    var body: some FileTreeWriter<TupleWriteSourceEvent> {
        FileTree {
            File("event", "txt")
                .convert(TupleWriteTrimmingConversion())

            Directory.Optional("stages") {
                File.Many(withExtension: "txt")
                    .map(FileContentConversion(TupleWriteTrimmingConversion()))
            }

            Directory.Optional("participants") {
                File.Many(withExtension: "txt")
                    .map(FileContentConversion(TupleWriteTrimmingConversion()))
            }
        }
        .convert(TupleWriteSourceEventConversion())
    }
}

private struct TupleWriteNestedRepository: Equatable {
    var calendar: TupleWriteCalendar?
    var events: [DirectoryContent<TupleWriteSourceEvent>]
}

private struct TupleWriteCalendar: Equatable {
    var name: String
    var description: String?
}

private struct TupleWriteSourceEvent: Equatable {
    var event: String
    var stages: [FileContent<String>]?
    var participants: [FileContent<String>]?
}

private struct TupleWriteNestedRepositoryConversion: Conversion {
    func apply(
        _ input: (TupleWriteCalendar?, [DirectoryContent<TupleWriteSourceEvent>])
    ) throws -> TupleWriteNestedRepository {
        TupleWriteNestedRepository(calendar: input.0, events: input.1)
    }

    func unapply(
        _ output: TupleWriteNestedRepository
    ) throws -> (TupleWriteCalendar?, [DirectoryContent<TupleWriteSourceEvent>]) {
        (output.calendar, output.events)
    }
}

private struct TupleWriteCalendarConversion: Conversion {
    func apply(_ input: Data) throws -> TupleWriteCalendar {
        TupleWriteCalendar(
            name: String(decoding: input, as: UTF8.self),
            description: nil
        )
    }

    func unapply(_ output: TupleWriteCalendar) throws -> Data {
        Data(output.name.utf8)
    }
}

private struct TupleWriteSourceEventConversion: Conversion {
    func apply(
        _ input: (
            String,
            [FileContent<String>]?,
            [FileContent<String>]?
        )
    ) throws -> TupleWriteSourceEvent {
        TupleWriteSourceEvent(
            event: input.0,
            stages: input.1,
            participants: input.2
        )
    }

    func unapply(
        _ output: TupleWriteSourceEvent
    ) throws -> (
        String,
        [FileContent<String>]?,
        [FileContent<String>]?
    ) {
        (
            output.event,
            output.stages,
            output.participants
        )
    }
}

private final class TupleWriteTemporaryDirectory {
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
