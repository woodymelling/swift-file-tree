//
//  Conversions.swift
//  swift-file-tree
//
//  Created by Woodrow Melling on 10/23/24.
//

import Conversions
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

import Conversions
import SwiftUI

public struct MapConversionComponent<Upstream: FileTreeComponent, Downstream: Conversion & Sendable>: FileTreeComponent
where Downstream.Input == Upstream.FileType, Downstream.Output: Sendable & Equatable {
    public let upstream: Upstream
    public let downstream: Downstream

    @inlinable
    public init(upstream: Upstream, downstream: Downstream) {
        self.upstream = upstream
        self.downstream = downstream
    }

    @inlinable
    @inline(__always)
    public func read(from url: URL) throws -> Downstream.Output {
        try self.downstream.apply(upstream.read(from: url))
    }

    public func write(_ data: Downstream.Output, to url: URL) throws {
        try self.upstream.write(downstream.unapply(data), to: url)
    }
}

extension MapConversionComponent: FileTreeViewable where Upstream: FileTreeViewable {
    public func view(for value: Downstream.Output) -> some View {
        ConversionView(
            upstream: upstream,
            downStreamUnapply: downstream.unapply,
            value: value
        )
    }

    struct ConversionView: View {
        @State var result: Result<Upstream.FileType, Error>?

        var upstream: Upstream
        var downStreamUnapply: @Sendable (Downstream.Output) async throws -> Upstream.FileType
        var value: Downstream.Output

        var body: some View {
            Group {
                if let result {
                    switch result {
                    case .success(let success):
                        upstream.view(for: success)
                    case .failure(let failure):
                        Text("ERROR")
                            .onAppear {
                                print(failure)
                            }
                    }
                } else {
                    Text("Loading...")
                }
            }
            .onChange(of: value, initial: true) { _, newValue in
                Task { @MainActor in
                    result = await Result(sendable: {
                        try await downStreamUnapply(newValue)
                    })
                }

            }
        }
    }
}

extension Result where Self: Sendable {
    init(sendable operation: @Sendable () async throws(Failure) -> Success) async {
        do {
            self = try await .success(operation())
        } catch {
            self = .failure(error)
        }
    }
}

extension FileTreeComponent {
    @inlinable
    public func convert<C>(_ conversion: C) -> MapConversionComponent<Self, C> {
        .init(upstream: self, downstream: conversion)
    }

    public func convert<C>(@ConversionBuilder build: () -> C) -> MapConversionComponent<Self, C> {
        self.convert(build())
    }
}
