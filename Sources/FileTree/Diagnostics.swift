import Foundation

public struct FileTreeLocation: Hashable, Sendable {
    public var path: String?

    public init(path: String? = nil) {
        self.path = path
    }
}

public struct FileTreeResult<Value: Sendable>: Sendable {
    public var output: Output
    public var diagnostics: DiagnosticReport<FileTreeLocation>

    public init(output: Output, diagnostics: DiagnosticReport<FileTreeLocation> = .init()) {
        self.output = output
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
        diagnostics: DiagnosticReport<FileTreeLocation> = .init()
    ) -> Self {
        Self(output: .value(value), diagnostics: diagnostics)
    }

    public static func invalid(diagnostics: DiagnosticReport<FileTreeLocation> = .init()) -> Self {
        Self(output: .invalid, diagnostics: diagnostics)
    }
}

extension FileTreeResult: Equatable where Value: Equatable {}
extension FileTreeResult.Output: Equatable where Value: Equatable {}

extension FileTreeResult.Output {
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

public struct Diagnostic<Location: Sendable>: Sendable {
    public var severity: Severity
    public var code: Code
    public var message: String
    public var location: Location?

    public init(
        severity: Severity,
        code: Code,
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
    public enum Severity: String, Hashable, Sendable {
        case error
        case warning
        case suggestion
        case note
    }

    public struct Code: Hashable, Sendable, RawRepresentable, ExpressibleByStringLiteral {
        public var rawValue: String

        public init(rawValue: String) {
            self.rawValue = rawValue
        }

        public init(stringLiteral value: StringLiteralType) {
            self.rawValue = value
        }
    }
}

private struct InvalidFileTreeOutput: Error {}

extension FileTreeResult.Output {
    var requiredValue: Value {
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
