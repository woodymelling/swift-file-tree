//
//  Inverted.swift
//  swift-parsing
//
//  Created by Woodrow Melling on 10/28/24.
//

extension Conversions {
  public struct Inverted<C: AsyncConversion>: AsyncConversion {
    public var conversion: C

    @inlinable
    public init(_ conversion: C) {
      self.conversion = conversion
    }

    @inlinable
    @inline(__always)
    public func apply(_ input: C.Output) async throws -> C.Input {
      try await conversion.unapply(input)
    }

    @inlinable
    @inline(__always)
    public func unapply(_ output: C.Input) async throws -> C.Output {
      try await conversion.apply(output)
    }
  }
}

extension Conversions.Inverted: Conversion where C: Conversion {
  @inlinable
  @inline(__always)
  public func apply(_ input: C.Output) throws -> C.Input {
    try conversion.unapply(input)
  }

  @inlinable
  @inline(__always)
  public func unapply(_ output: C.Input) throws -> C.Output {
    try conversion.apply(output)
  }
}

public extension Conversion {
  @inlinable
  @inline(__always)
  func inverted() -> Conversions.Inverted<Self> {
    Conversions.Inverted(self)
  }
}
