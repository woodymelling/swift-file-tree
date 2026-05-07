import Foundation

public struct FileTreeLocation: Hashable, Sendable {
    public var path: String?
    public var handle: SourceGraph.Handle?
    public var sourceLocation: SourceGraph.Location?

    public init(
        path: String? = nil,
        handle: SourceGraph.Handle? = nil,
        sourceLocation: SourceGraph.Location? = nil
    ) {
        self.path = path
        self.handle = handle
        self.sourceLocation = sourceLocation
    }

    public func resolved(in graph: SourceGraph) -> SourceGraph.Location? {
        if let sourceLocation {
            return sourceLocation
        }

        if let handle, let location = graph.location(for: handle) {
            return location
        }

        if let path {
            return SourceGraph.Location(path: SourceGraph.Path(rawValue: path))
        }

        return nil
    }
}

public struct FileTreeResult<Value: Sendable>: Sendable {
    public var output: Output
    public var graph: SourceGraph
    public var diagnostics: DiagnosticReport<FileTreeLocation>

    public init(
        output: Output,
        graph: SourceGraph = .init(),
        diagnostics: DiagnosticReport<FileTreeLocation> = .init()
    ) {
        self.output = output
        self.graph = graph
        self.diagnostics = diagnostics
    }

    public enum Output: Sendable {
        case value(Value)
        case invalid
    }
}

extension FileTreeResult {
    public static func value(
        _ value: Value,
        graph: SourceGraph = .init(),
        diagnostics: DiagnosticReport<FileTreeLocation> = .init()
    ) -> Self {
        Self(output: .value(value), graph: graph, diagnostics: diagnostics)
    }

    public static func invalid(
        graph: SourceGraph = .init(),
        diagnostics: DiagnosticReport<FileTreeLocation> = .init()
    ) -> Self {
        Self(output: .invalid, graph: graph, diagnostics: diagnostics)
    }
}

extension FileTreeResult: Equatable where Value: Equatable {}
extension FileTreeResult.Output: Equatable where Value: Equatable {}

extension FileTreeResult.Output {
    public func map<NewValue>(_ transform: (Value) -> NewValue) -> FileTreeResult<NewValue>.Output {
        switch self {
        case let .value(value):
            .value(transform(value))
        case .invalid:
            .invalid
        }
    }

    public var isInvalid: Bool {
        switch self {
        case .value:
            false
        case .invalid:
            true
        }
    }
}

public struct DiagnosticReport<Location: Sendable>: Sendable {
    public var diagnostics: [Diagnostic<Location>]

    public init(diagnostics: [Diagnostic<Location>] = []) {
        self.diagnostics = diagnostics
    }

    public var isEmpty: Bool {
        diagnostics.isEmpty
    }

    public var hasErrors: Bool {
        diagnostics.contains { $0.severity == .error }
    }

    public mutating func append(_ diagnostic: Diagnostic<Location>) {
        diagnostics.append(diagnostic)
    }

    public mutating func append(contentsOf other: DiagnosticReport<Location>) {
        diagnostics.append(contentsOf: other.diagnostics)
    }

    public func merging(_ other: DiagnosticReport<Location>) -> Self {
        var copy = self
        copy.append(contentsOf: other)
        return copy
    }
}

extension DiagnosticReport: Equatable where Location: Equatable {}

extension DiagnosticReport where Location == FileTreeLocation {
    public func resolved(in graph: SourceGraph) -> DiagnosticReport<SourceGraph.Location> {
        DiagnosticReport<SourceGraph.Location>(
            diagnostics: diagnostics.map { diagnostic in
                Diagnostic<SourceGraph.Location>(
                    severity: diagnostic.severity,
                    code: diagnostic.code,
                    message: diagnostic.message,
                    location: diagnostic.location?.resolved(in: graph)
                )
            }
        )
    }
}

public struct Diagnostic<Location: Sendable>: Sendable {
    public var severity: DiagnosticSeverity
    public var code: DiagnosticCode
    public var message: String
    public var location: Location?

    public init(
        severity: DiagnosticSeverity,
        code: DiagnosticCode,
        message: String,
        location: Location? = nil
    ) {
        self.severity = severity
        self.code = code
        self.message = message
        self.location = location
    }
}

extension Diagnostic: Equatable where Location: Equatable {}

extension Diagnostic {
    public typealias Severity = DiagnosticSeverity
    public typealias Code = DiagnosticCode
}

public enum DiagnosticSeverity: String, Hashable, Sendable {
    case error
    case warning
    case suggestion
    case note
}

public struct DiagnosticCode: Hashable, Sendable, RawRepresentable, ExpressibleByStringLiteral {
    public var rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(stringLiteral value: StringLiteralType) {
        self.rawValue = value
    }
}

private struct InvalidFileTreeOutput: Error {}

extension FileTreeResult.Output {
    public var requiredValue: Value {
        get throws {
            switch self {
            case let .value(value):
                value
            case .invalid:
                throw InvalidFileTreeOutput()
            }
        }
    }
}
