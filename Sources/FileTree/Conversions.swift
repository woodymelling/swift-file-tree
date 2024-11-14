//
//  Conversions.swift
//  swift-file-tree
//
//  Created by Woodrow Melling on 10/23/24.
//

import Parsing
import Foundation

/**
 FileContentConversion {
     Conversions.YamlConversion(EventDTO.DaySchedule.self)
 }
 */
public struct FileContentConversion<AppliedConversion: Conversion>: Conversion {
    public typealias Input = FileContent<AppliedConversion.Input>
    public typealias Output = FileContent<AppliedConversion.Output>

    var conversion: AppliedConversion

    public init(_ converson: AppliedConversion) {
        self.conversion = converson
    }

    public init(@ConversionBuilder build: () -> AppliedConversion) {
        self.conversion = build()
    }

    public func apply(_ input: FileContent<AppliedConversion.Input>) throws -> FileContent<AppliedConversion.Output> {
        try input.map { try self.conversion.apply($0) }
    }

    public func unapply(_ output: FileContent<AppliedConversion.Output>) throws -> FileContent<AppliedConversion.Input> {
        try output.map { try self.conversion.unapply($0) }
    }
}

extension FileContentConversion: Sendable where AppliedConversion: Sendable {}

//
//public struct Map<Upstream: FileTreeComponent, NewOutput: Sendable>: FileTreeComponent {
//    public let upstream: Upstream
//    public let transform: @Sendable (Upstream.FileType) throws -> NewOutput
//
//    public func read(from url: URL) async throws -> NewOutput {
//        try await self.transform(upstream.read(from: url))
//    }
//
//    public func write(_ data: NewOutput, to url: URL) async throws {
//        try await upstream.write(self.transform(data), to: url)
//    }
//}

import Parsing

public struct MapConversionComponent<Upstream: FileTreeComponent, Downstream: AsyncConversion & Sendable>: FileTreeComponent
where Downstream.Input == Upstream.FileType, Downstream.Output: Sendable {
    public let upstream: Upstream
    public let downstream: Downstream

    @inlinable
    public init(upstream: Upstream, downstream: Downstream) {
        self.upstream = upstream
        self.downstream = downstream
    }

    @inlinable
    @inline(__always)
    public func read(from url: URL) async throws -> Downstream.Output {
        try await self.downstream.apply(upstream.read(from: url))
    }

    public func write(_ data: Downstream.Output, to url: URL) async throws {
        try await self.upstream.write(downstream.unapply(data), to: url)
    }
}

extension FileTreeComponent {
//    public func map<NewOutput>(
//        _ transform: @escaping @Sendable (FileType) throws -> NewOutput
//    ) -> Map<Self, NewOutput> {
//        .init(upstream: self, transform: transform)
//    }

    @inlinable
    public func map<C>(_ conversion: C) -> MapConversionComponent<Self, C> {
        .init(upstream: self, downstream: conversion)
    }

    public func map<C>(@ConversionBuilder build: () -> C) -> MapConversionComponent<Self, C> {
        self.map(build())
    }
}
