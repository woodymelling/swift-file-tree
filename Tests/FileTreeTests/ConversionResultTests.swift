import Foundation
@testable import FileTree
import Testing

struct ConversionResultTests {
    @Test func conversionResultCanCarryValueAndDiagnostics() {
        let result = Conversions.Result<String>.value(
            "Wicked Woods",
            diagnostics: .init(
                diagnostics: [
                    .init(
                        severity: .warning,
                        code: "ome.event.description.missing",
                        message: "Description is missing"
                    )
                ]
            )
        )

        #expect(result.output == .value("Wicked Woods"))
        #expect(result.diagnostics.diagnostics.map(\.code.rawValue) == ["ome.event.description.missing"])
    }

    @Test func convertedReaderMergesDiagnosticsFromConversionResult() throws {
        let directory = try ConversionTemporaryDirectory()
        try Data("Wicked Woods".utf8)
            .write(to: directory.url.appendingPathComponent("event", withType: "txt"))

        let result = try File("event", "txt")
            .convert(WarningEventNameConversion())
            .read(from: directory.url)

        #expect(result.output == .value("Wicked Woods"))
        #expect(result.diagnostics.diagnostics.map(\.code.rawValue) == ["ome.event.description.missing"])
    }

    @Test func convertedReaderReturnsInvalidFromConversionResult() throws {
        let directory = try ConversionTemporaryDirectory()
        try Data("".utf8)
            .write(to: directory.url.appendingPathComponent("event", withType: "txt"))

        let result = try File("event", "txt")
            .convert(RequiredEventNameConversion())
            .read(from: directory.url)

        #expect(result.output.isInvalid)
        #expect(result.diagnostics.diagnostics.map(\.code.rawValue) == ["ome.event.name.required"])
    }

    @Test func defaultPrintFailureReturnsInvalidDiagnostic() {
        let result = FailingPrintConversion().unapply("Wicked Woods", in: .init())

        #expect(result.output.isInvalid)
        #expect(result.diagnostics.diagnostics.map(\.code.rawValue) == ["file-tree.conversion.print.failed"])
    }

    @Test func mappedConversionMergesDiagnosticsFromBothConversions() {
        let conversion = WarningEventNameConversion()
            .map(UppercaseEventNameConversion())

        let result = conversion.apply(Data("Wicked Woods".utf8), in: .init())

        #expect(result.output == .value("WICKED WOODS"))
        #expect(
            result.diagnostics.diagnostics.map(\.code.rawValue)
            == [
                "ome.event.description.missing",
                "ome.event.name.normalized",
            ]
        )
    }

    @Test func convertedWriteUsesDiagnosticAwareUnapply() throws {
        let directory = try ConversionTemporaryDirectory()

        let result = try File("event", "txt")
            .convert(TrimmingEventNameConversion())
            .write("  Wicked Woods  ", to: directory.url)

        let data = try Data(contentsOf: directory.url.appendingPathComponent("event", withType: "txt"))

        #expect(result.output == .value("  Wicked Woods  "))
        #expect(String(decoding: data, as: UTF8.self) == "Wicked Woods")
    }

    @Test func convertedWriteWarningStillWritesFile() throws {
        let directory = try ConversionTemporaryDirectory()

        let result = try File("event", "txt")
            .convert(WarningPrintEventNameConversion())
            .write("Wicked Woods", to: directory.url)

        let data = try Data(contentsOf: directory.url.appendingPathComponent("event", withType: "txt"))

        #expect(result.output == .value("Wicked Woods"))
        #expect(String(decoding: data, as: UTF8.self) == "Wicked Woods")
        #expect(result.diagnostics.diagnostics.map(\.code.rawValue) == ["ome.event.name.printed"])
    }

    @Test func convertedWriteErrorReturnsInvalidAndDoesNotWrite() throws {
        let directory = try ConversionTemporaryDirectory()

        let result = try File("event", "txt")
            .convert(FailingPrintEventNameConversion())
            .write("Wicked Woods", to: directory.url)

        #expect(result.output.isInvalid)
        #expect(!FileManager.default.fileExists(atPath: directory.url.appendingPathComponent("event", withType: "txt").path()))
        #expect(result.diagnostics.diagnostics.map(\.code.rawValue) == ["ome.event.name.unprintable"])
    }
}

private struct WarningEventNameConversion: Conversion {
    func apply(_ input: Data) throws -> String {
        String(decoding: input, as: UTF8.self)
    }

    func apply(_ input: Data, in graph: SourceGraph) -> Conversions.Result<String> {
        .value(
            String(decoding: input, as: UTF8.self),
            diagnostics: .init(
                diagnostics: [
                    .init(
                        severity: .warning,
                        code: "ome.event.description.missing",
                        message: "Description is missing"
                    )
                ]
            )
        )
    }

    func unapply(_ output: String) throws -> Data {
        Data(output.utf8)
    }
}

private struct RequiredEventNameConversion: Conversion {
    func apply(_ input: Data) throws -> String {
        String(decoding: input, as: UTF8.self)
    }

    func apply(_ input: Data, in graph: SourceGraph) -> Conversions.Result<String> {
        let value = String(decoding: input, as: UTF8.self)
        guard !value.isEmpty else {
            return .invalid(
                diagnostics: .init(
                    diagnostics: [
                        .init(
                            severity: .error,
                            code: "ome.event.name.required",
                            message: "Event name is required"
                        )
                    ]
                )
            )
        }
        return .value(value)
    }

    func unapply(_ output: String) throws -> Data {
        Data(output.utf8)
    }
}

private struct FailingPrintConversion: Conversion {
    func apply(_ input: Data) throws -> String {
        String(decoding: input, as: UTF8.self)
    }

    func unapply(_ output: String) throws -> Data {
        throw PrintFailed()
    }

    struct PrintFailed: Error {}
}

private struct UppercaseEventNameConversion: Conversion {
    func apply(_ input: String) throws -> String {
        input.uppercased()
    }

    func apply(_ input: String, in graph: SourceGraph) -> Conversions.Result<String> {
        .value(
            input.uppercased(),
            diagnostics: .init(
                diagnostics: [
                    .init(
                        severity: .warning,
                        code: "ome.event.name.normalized",
                        message: "Event name was normalized"
                    )
                ]
            )
        )
    }

    func unapply(_ output: String) throws -> String {
        output
    }
}

private struct TrimmingEventNameConversion: Conversion {
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

private struct WarningPrintEventNameConversion: Conversion {
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
                        code: "ome.event.name.printed",
                        message: "Event name was printed"
                    )
                ]
            )
        )
    }
}

private struct FailingPrintEventNameConversion: Conversion {
    func apply(_ input: Data) throws -> String {
        String(decoding: input, as: UTF8.self)
    }

    func unapply(_ output: String) throws -> Data {
        Data(output.utf8)
    }

    func unapply(_ output: String, in graph: SourceGraph) -> Conversions.Result<Data> {
        .invalid(
            diagnostics: .init(
                diagnostics: [
                    .init(
                        severity: .error,
                        code: "ome.event.name.unprintable",
                        message: "Event name cannot be printed"
                    )
                ]
            )
        )
    }
}

private final class ConversionTemporaryDirectory {
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
