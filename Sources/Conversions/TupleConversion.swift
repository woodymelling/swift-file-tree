//
//  TupleConversion.swift
//  OpenFestival
//
//  Created by Woodrow Melling on 10/25/24.
//

public extension Conversions {

  struct Tuple<each C: AsyncConversion>: AsyncConversion {
    public typealias Input = (repeat (each C).Input)
    public typealias Output = (repeat (each C).Output)

    let conversions: (repeat each C)

    public init(_ conversions: repeat each C) {
      self.conversions = (repeat each conversions)
    }

    public func apply(_ inputs: Input) async throws -> Output {
      func apply<T: AsyncConversion>(conversion: T, to input: T.Input) async throws -> T.Output {
        try await conversion.apply(input)
      }

      return (repeat try await apply(conversion: each conversions, to: each inputs))
    }

    public func unapply(_ output: (repeat (each C).Output)) async throws -> (repeat (each C).Input) {
      func unapply<T: AsyncConversion>(conversion: T, to output: T.Output) async throws -> T.Input {
        try await conversion.unapply(output)
      }

      return (repeat try await unapply(conversion: each conversions, to: each output))
    }
  }
}

extension Conversions.Tuple: Conversion where repeat (each C): Conversion {
  public func apply(_ inputs: Input) throws -> Output {
      func apply<T: Conversion>(conversion: T, to input: T.Input) throws -> T.Output {
          try conversion.apply(input)
      }

      return (repeat try apply(conversion: each conversions, to: each inputs))
  }

  public func unapply(_ output: (repeat (each C).Output)) throws -> (repeat (each C).Input) {
      func unapply<T: Conversion>(conversion: T, to output: T.Output) throws -> T.Input {
          try conversion.unapply(output)
      }

      return (repeat try unapply(conversion: each conversions, to: each output))
  }
}


