

/// Declares a type that can asynchronously transform an `Input` value into an `Output` value *and* transform an
/// `Output` value back into an `Input` value.
///
/// Useful in bidirectionally tranforming types, like when writing something to the disk.
/// printability via ``Parser/map(_:)-18m9d``.
@rethrows public protocol AsyncConversion<Input, Output>: Sendable {
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
  @Sendable func apply(_ input: Input) async throws -> Output

  /// Attempts to asynchronously transform an output back into an input.
  ///
  /// The reverse process of ``Conversion/apply(_:)``.
  ///
  /// - Parameter output: An output value.
  /// - Returns: An "un"-transformed input value.
  @Sendable func unapply(_ input: Output) async throws -> Input

  @ConversionBuilder
  var body: Body { get }
}

/// Declares a type that can transform an `Input` value into an `Output` value *and* transform an
/// `Output` value back into an `Input` value.
///
/// Useful in transforming the output of a parser-printer into some new type while preserving
/// printability via ``Parser/map(_:)-18m9d``.
@rethrows public protocol Conversion<Input, Output>: AsyncConversion {
  // The type of values this conversion converts from.
  associatedtype Input

  // The type of values this conversion converts to.
  associatedtype Output


  /// Attempts to transform an input into an output.
  ///
  /// See ``Conversion/apply(_:)`` for the reverse process.
  ///
  /// - Parameter input: An input value.
  /// - Returns: A transformed output value.
  @Sendable func apply(_ input: Input) throws -> Output

  /// Attempts to transform an output back into an input.
  ///
  /// The reverse process of ``Conversion/apply(_:)``.
  ///
  /// - Parameter output: An output value.
  /// - Returns: An "un"-transformed input value.
  @Sendable func unapply(_ output: Output) throws -> Input
}

extension AsyncConversion
where Body: AsyncConversion, Body.Input == Input, Body.Output == Output {
  public func apply(_ input: Input) async throws -> Output {
    try await self.body.apply(input)
  }

  public func unapply(_ output: Output) async throws -> Input {
    try await self.body.unapply(output)
  }
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

extension AsyncConversion where Body == Never {
  public var body: Body {
    return fatalError("Body of \(Self.self) should never be called")
  }
}



