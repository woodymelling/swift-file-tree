/// Declares a type that can asynchronously transform an `Input` value into an `Output` value *and* transform an
/// `Output` value back into an `Input` value.
///
/// Useful in bidirectionally tranforming types, like when writing something to the disk.
/// printability via ``Parser/map(_:)-18m9d``.
@rethrows public protocol Conversion<Input, Output>: Sendable {
  // The type of values this conversion converts from.
  associatedtype Input

  // The type of values this conversion converts to.
  associatedtype Output

  associatedtype Body

  /// Attempts to asynchronously transform an input into an output.
  ///
  /// See ``Conversion/apply(_:)`` for the reverse process.
  ///
  /// - Parameter input: An input value.
  /// - Returns: A transformed output value.
  @Sendable func apply(_ input: Input) throws -> Output

  /// Attempts to asynchronously transform an output back into an input.
  ///
  /// The reverse process of ``Conversion/apply(_:)``.
  ///
  /// - Parameter output: An output value.
  /// - Returns: An "un"-transformed input value.
  @Sendable func unapply(_ input: Output) throws -> Input

  @Sendable func apply(_ input: Input, in graph: SourceGraph) -> Conversions.Result<Output>

  @Sendable func unapply(_ input: Output, in graph: SourceGraph) -> Conversions.Result<Input>

  @Sendable func unapply(_ input: Output, in context: FileTreeWriteContext) -> Conversions.Result<Input>

  @ConversionBuilder
  var body: Body { get }
}

extension Conversion
where Body: Conversion, Body.Input == Input, Body.Output == Output {
  public func apply(_ input: Input) throws -> Output {
    try self.body.apply(input)
  }

  public func unapply(_ output: Output) throws -> Input {
    try self.body.unapply(output)
  }

  public func apply(_ input: Input, in graph: SourceGraph) -> Conversions.Result<Output> {
    self.body.apply(input, in: graph)
  }

  public func unapply(_ output: Output, in graph: SourceGraph) -> Conversions.Result<Input> {
    self.body.unapply(output, in: graph)
  }

  public func unapply(_ output: Output, in context: FileTreeWriteContext) -> Conversions.Result<Input> {
    self.body.unapply(output, in: context)
  }
}

extension Conversion where Body == Never {
  public var body: Body {
    return fatalError("Body of \(Self.self) should never be called")
  }
}

/// A namespace for types that serve as conversions.
///
/// The various operators defined as extensions on ``Conversion`` implement their functionality as
/// classes or structures that extend this enumeration. For example, the ``Conversion/map(_:)``
/// operator returns a ``Map`` conversion.
public enum Conversions {}

extension Conversions {
  public struct Result<Value> {
    public var output: FileTreeResult<Value>.Output
    public var diagnostics: DiagnosticReport<FileTreeLocation>

    public init(
      output: FileTreeResult<Value>.Output,
      diagnostics: DiagnosticReport<FileTreeLocation> = .init()
    ) {
      self.output = output
      self.diagnostics = diagnostics
    }
  }
}

extension Conversions.Result: Sendable where Value: Sendable {}

extension Conversions.Result {
  public static func value(
    _ value: Value,
    diagnostics: DiagnosticReport<FileTreeLocation> = .init()
  ) -> Self {
    Self(output: .value(value), diagnostics: diagnostics)
  }

  public static func invalid(
    diagnostics: DiagnosticReport<FileTreeLocation>
  ) -> Self {
    Self(output: .invalid, diagnostics: diagnostics)
  }
}

extension Conversions.Result: Equatable where Value: Equatable {}

extension Conversion {
  public func apply(_ input: Input, in graph: SourceGraph) -> Conversions.Result<Output> {
    do {
      return .value(try apply(input))
    } catch {
      return .invalid(
        diagnostics: .init(
          diagnostics: [
            Diagnostic(
              severity: .error,
              code: "file-tree.conversion.failed",
              message: String(describing: error)
            )
          ]
        )
      )
    }
  }

  public func unapply(_ output: Output, in graph: SourceGraph) -> Conversions.Result<Input> {
    do {
      return .value(try unapply(output))
    } catch {
      return .invalid(
        diagnostics: .init(
          diagnostics: [
            Diagnostic(
              severity: .error,
              code: "file-tree.conversion.print.failed",
              message: String(describing: error)
            )
          ]
        )
      )
    }
  }

  public func unapply(_ output: Output, in context: FileTreeWriteContext) -> Conversions.Result<Input> {
    unapply(output, in: context.graph)
  }
}
