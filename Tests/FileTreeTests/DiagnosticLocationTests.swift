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
}
