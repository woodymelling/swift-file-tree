extension Conversion {
  /// Returns a conversion that transforms the output of this conversion with a given downstream
  /// conversion.
  ///
  /// When provided with a conversion from this conversion's output type to some new output type,
  /// this method can return a new conversion from this conversion's input type to the given
  /// conversion's output type by calling their ``apply(_:)`` functions and ``unapply(_:)``
  /// functions one after the other.
  ///
  /// This method is similar to `Sequence.map`, `Optional.map`, and `Result.map` in the Swift
  /// standard library, as well as `Publisher.map` in the Combine framework. This method is also
  /// similar to the `map` functions on ``Parser`` and ``ParserPrinter``, especially
  /// ``Parser/map(_:)-18m9d``, which takes a conversion.
  ///
  /// - Parameter downstream: A conversion that transforms the output of this conversion into some
  ///   new output.
  /// - Returns: A conversion that transforms the input of this conversion into the output of the
  ///   given conversion.
  @inlinable
  public func map<C>(_ downstream: C) -> Conversions.Map<Self, C> {
    .init(upstream: self, downstream: downstream)
  }
}

extension Conversions {
  /// A conversion that composes two conversions together by composing their
  /// ``Conversion/apply(_:)`` functions and ``Conversion/unapply(_:)`` functions together.
  ///
  /// You will not typically need to interact with this type directly. Instead you will usually use
  /// the ``Conversion/map(_:)`` operation, which constructs this type.
  public struct Map<Upstream: Conversion, Downstream: Conversion>: Conversion
  where Upstream.Output == Downstream.Input {
    public let upstream: Upstream
    public let downstream: Downstream

    @usableFromInline
    init(upstream: Upstream, downstream: Downstream) {
      self.upstream = upstream
      self.downstream = downstream
    }

    @inlinable
    @inline(__always)
    public func apply(_ input: Upstream.Input) rethrows -> Downstream.Output {
      try self.downstream.apply(self.upstream.apply(input))
    }

    public func apply(_ input: Upstream.Input, in graph: SourceGraph) -> Conversions.Result<Downstream.Output> {
      let upstreamResult = upstream.apply(input, in: graph)
      var diagnostics = upstreamResult.diagnostics

      switch upstreamResult.output {
      case let .value(upstreamOutput) where !diagnostics.hasErrors:
        let downstreamResult = downstream.apply(upstreamOutput, in: graph)
        diagnostics.append(contentsOf: downstreamResult.diagnostics)

        switch downstreamResult.output {
        case let .value(output) where !diagnostics.hasErrors:
          return .value(output, diagnostics: diagnostics)
        case .value, .invalid:
          return .invalid(diagnostics: diagnostics)
        }

      case .value, .invalid:
        return .invalid(diagnostics: diagnostics)
      }
    }

    @inlinable
    @inline(__always)
    public func unapply(_ output: Downstream.Output) rethrows -> Upstream.Input {
      try self.upstream.unapply(self.downstream.unapply(output))
    }

    public func unapply(_ output: Downstream.Output, in graph: SourceGraph) -> Conversions.Result<Upstream.Input> {
      let downstreamResult = downstream.unapply(output, in: graph)
      var diagnostics = downstreamResult.diagnostics

      switch downstreamResult.output {
      case let .value(downstreamInput) where !diagnostics.hasErrors:
        let upstreamResult = upstream.unapply(downstreamInput, in: graph)
        diagnostics.append(contentsOf: upstreamResult.diagnostics)

        switch upstreamResult.output {
        case let .value(input) where !diagnostics.hasErrors:
          return .value(input, diagnostics: diagnostics)
        case .value, .invalid:
          return .invalid(diagnostics: diagnostics)
        }

      case .value, .invalid:
        return .invalid(diagnostics: diagnostics)
      }
    }
  }
}
