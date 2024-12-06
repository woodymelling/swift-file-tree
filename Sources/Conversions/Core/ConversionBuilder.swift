//
//  ConversionBuilder.swift
//  swift-parsing
//
//  Created by Woodrow Melling on 10/24/24.
//

@resultBuilder
public enum ConversionBuilder<Input, Output> {
    public static func buildBlock<T>() -> Conversions.Identity<T> {
        Conversions.Identity()
    }
    public static func buildPartialBlock<C: AsyncConversion<Input, Output>>(first conversion: C) -> C {
        conversion
    }

    public static func buildPartialBlock<
        Internal,
        C0: AsyncConversion<Input, Internal>,
        C1: AsyncConversion<Internal, Input>
    >(
        accumulated c0: C0,
        next c1: C1
    ) -> Conversions.Map<C0, C1> where C0.Output == C1.Input {
        Conversions.Map(upstream: c0, downstream: c1)
    }
}
