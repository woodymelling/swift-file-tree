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
