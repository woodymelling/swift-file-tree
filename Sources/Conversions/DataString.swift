//
//  DataString.swift
//  OpenFestival
//
//  Created by Woodrow Melling on 10/25/24.
//

import Foundation
import Conversions

extension Conversions {
    public struct DataToString: Conversion {
        public typealias Input = Data
        public typealias Output = String
        public init() {}

        public func apply(_ input: Data) throws -> String {
            String(decoding: input, as: UTF8.self)
        }

        public func unapply(_ output: String) throws -> Data {
            Data(output.utf8)
        }
    }
}
