import Foundation
@testable import FileTree
import Testing

struct DiagnosticLocationTests {
    @Test func diagnosticCanPointAtLogicalFieldHandle() {
        let handle = SourceGraph.Handle(nodeID: .init(rawValue: "logical:ome.event:wicked-woods"))
            .field("name")

        let diagnostic = Diagnostic<FileTreeLocation>(
            severity: .error,
            code: "ome.event.name.required",
            message: "Event name is required",
            location: .init(handle: handle)
        )

        #expect(diagnostic.location?.handle == handle)
    }

    @Test func reportResolvesHandleLocationThroughSourceGraph() {
        let fileID = SourceGraph.Node.ID(.file("event.yaml"))
        let logicalID = SourceGraph.Node.ID(
            .logical(kind: "ome.event", key: "wicked-woods")
        )
        let handle = SourceGraph.Handle(nodeID: logicalID).field("name")
        let graph = SourceGraph(
            nodes: [
                fileID: .init(identity: .file("event.yaml")),
                logicalID: .init(identity: .logical(kind: "ome.event", key: "wicked-woods")),
            ],
            edges: [
                .init(source: fileID, target: logicalID, kind: .parsedFrom)
            ]
        )
        let report = DiagnosticReport(
            diagnostics: [
                Diagnostic<FileTreeLocation>(
                    severity: .error,
                    code: "ome.event.name.required",
                    message: "Event name is required",
                    location: .init(handle: handle)
                )
            ]
        )

        #expect(report.resolved(in: graph).diagnostics.first?.location == .init(path: "event.yaml"))
    }

    @Test func explicitSourceLocationWinsWhenProvided() {
        let handle = SourceGraph.Handle(nodeID: SourceGraph.Node.ID(.file("fallback.yaml")))
        let report = DiagnosticReport(
            diagnostics: [
                Diagnostic<FileTreeLocation>(
                    severity: .warning,
                    code: "ome.event.description.missing",
                    message: "Description is missing",
                    location: .init(
                        handle: handle,
                        sourceLocation: .init(
                            path: "event.yaml",
                            span: .init(start: .init(line: 4, column: 9))
                        )
                    )
                )
            ]
        )
        let graph = SourceGraph.node(.file("fallback.yaml"))

        #expect(
            report.resolved(in: graph).diagnostics.first?.location
            == .init(path: "event.yaml", span: .init(start: .init(line: 4, column: 9)))
        )
    }

    @Test func directoryReadPrefixesDiagnosticSourceLocations() throws {
        let directory = try DiagnosticTemporaryDirectory()
        let eventURL = directory.url.appending(component: "event", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: eventURL, withIntermediateDirectories: true)
        try Data("broken".utf8).write(to: eventURL.appendingPathComponent("event-info", withType: "yml"))

        let result = try Directory("event") {
            File("event-info", "yml")
                .convert(LocationDiagnosticConversion())
        }
        .read(from: directory.url)

        #expect(result.output.isInvalid)
        #expect(
            result.diagnostics.resolved(in: result.graph).diagnostics.first?.location?.path
            == "event/event-info.yml"
        )
    }

    @Test func optionalDirectoryReadPrefixesDiagnosticSourceLocations() throws {
        let directory = try DiagnosticTemporaryDirectory()
        let schedulesURL = directory.url.appending(component: "schedules", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: schedulesURL, withIntermediateDirectories: true)
        try Data("broken".utf8).write(to: schedulesURL.appendingPathComponent("friday", withType: "yml"))

        let result = try Directory.Optional("schedules") {
            File("friday", "yml")
                .convert(LocationDiagnosticConversion())
        }
        .read(from: directory.url)

        #expect(result.output.isInvalid)
        #expect(
            result.diagnostics.resolved(in: result.graph).diagnostics.first?.location?.path
            == "schedules/friday.yml"
        )
    }

    @Test func directoryManyRetainsInvalidChildGraphAndPrefixesDiagnostics() throws {
        let directory = try DiagnosticTemporaryDirectory()
        let eventURL = directory.url.appending(component: "event", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: eventURL, withIntermediateDirectories: true)
        try Data("broken".utf8).write(to: eventURL.appendingPathComponent("event-info", withType: "yml"))

        let result = try Directory.Many {
            File("event-info", "yml")
                .convert(LocationDiagnosticConversion())
        }
        .read(from: directory.url)

        #expect(result.output.isInvalid)
        #expect(result.graph.containsNode(.directory("event")))
        #expect(result.graph.containsNode(.file("event/event-info.yml")))
        #expect(
            result.diagnostics.resolved(in: result.graph).diagnostics.first?.location?.path
            == "event/event-info.yml"
        )
    }
}

private struct LocationDiagnosticConversion: Conversion {
    func apply(_ input: Data) throws -> String {
        throw DecodeFailed()
    }

    func apply(_ input: Data, in graph: SourceGraph) -> Conversions.Result<String> {
        .invalid(
            diagnostics: .init(
                diagnostics: [
                    Diagnostic(
                        severity: .error,
                        code: "test.decode.failed",
                        message: "Decode failed",
                        location: graph.root
                            .flatMap { graph.location(for: .init(nodeID: $0)) }
                            .map { FileTreeLocation(sourceLocation: $0) }
                    )
                ]
            )
        )
    }

    func unapply(_ output: String) -> Data {
        Data(output.utf8)
    }

    private struct DecodeFailed: Error {}
}

private final class DiagnosticTemporaryDirectory {
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
