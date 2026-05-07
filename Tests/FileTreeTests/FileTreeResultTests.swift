import Foundation
@testable import FileTree
import Testing

struct FileTreeResultTests {
    @Test func fileReadReturnsValueAndNoDiagnostics() throws {
        let directory = try TemporaryDirectory()
        try Data("Hello".utf8).write(to: directory.url.appendingPathComponent("Greeting", withType: "txt"))

        let result = try File("Greeting", "txt").read(from: directory.url)

        #expect(result.output == .value(Data("Hello".utf8)))
        #expect(result.diagnostics.isEmpty)
    }

    @Test func missingRequiredFileStillThrowsInfrastructureError() throws {
        let directory = try TemporaryDirectory()

        #expect(throws: Error.self) {
            _ = try File("Missing", "txt").read(from: directory.url)
        }
    }

    @Test func conversionFailureReturnsInvalidOutputAndDiagnostic() throws {
        struct FailingConversion: Conversion {
            func apply(_ input: Data) throws -> String {
                throw ConversionFailed()
            }

            func unapply(_ output: String) throws -> Data {
                Data(output.utf8)
            }

            struct ConversionFailed: Error {}
        }

        let directory = try TemporaryDirectory()
        try Data("Hello".utf8).write(to: directory.url.appendingPathComponent("Greeting", withType: "txt"))

        let result = try File("Greeting", "txt")
            .convert(FailingConversion())
            .read(from: directory.url)

        #expect(result.output.isInvalid)
        #expect(result.diagnostics.hasErrors)
        #expect(result.diagnostics.diagnostics.map(\.code.rawValue) == ["file-tree.conversion.failed"])
    }

    @Test func tupleReadMergesDiagnosticsFromChildren() throws {
        struct FailingConversion: Conversion {
            func apply(_ input: Data) throws -> String {
                throw ConversionFailed()
            }

            func unapply(_ output: String) throws -> Data {
                Data(output.utf8)
            }

            struct ConversionFailed: Error {}
        }

        let directory = try TemporaryDirectory()
        try Data("Good".utf8).write(to: directory.url.appendingPathComponent("Good", withType: "txt"))
        try Data("Bad".utf8).write(to: directory.url.appendingPathComponent("Bad", withType: "txt"))

        let tree = FileTree {
            File("Good", "txt")
            File("Bad", "txt").convert(FailingConversion())
        }

        let result = try tree.read(from: directory.url)

        #expect(result.output.isInvalid)
        #expect(result.diagnostics.hasErrors)
        #expect(result.diagnostics.diagnostics.count == 1)
    }
}

private final class TemporaryDirectory {
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
