////
////  ZipErrors.swift
////  swift-file-tree
////
////  Created by Woodrow Melling on 10/30/24.
////
//
//
//import Testing
//@testable import FileTree
//import XCTest
//
//
//struct E: Error, Equatable {
//    init(_ id: Int) {
//        self.id = id
//    }
//    var id: Int
//}
//
//struct ZipTests {
//
//    @Test
//    func allSucceeds() throws {
//
//        let (a, b) = try allSucceed(
//            { return 1 },
//            { return 2 }
//        )
//
//        #expect(a == 1)
//        #expect(b == 2)
//    }
//
//    @Test
//    func allResultsSucceeds() throws {
//
//        let (a, b) = try allSucceed(
//            Result.success(1),
//            Result.success(2)
//        )
//
//        #expect(a == 1)
//        #expect(b == 2)
//    }
//
//    @Test
//    func results() throws {
//        #expect(throws: Errors([E(0)])!) {
//
//            try allSucceed(
//                Result<Int, Error>.success(1),
//                Result<Int, Error>.failure(E(0))
//            )
//        }
//    }
//
//    @Test
//    func oneFails() throws {
//        #expect(throws: Errors(E(1))!) {
//            let (_, b: ()) = try allSucceed(
//                { return 1 },
//                { throw E(1) }
//            )
//        }
//    }
//
//    @Test
//    func zipTwoThrows() {
//
//        #expect(throws: Errors([E(0), E(1)])!) {
//            let (a: (), b: ()) = try allSucceed(
//                { throw E(0) },
//                { throw E(1) }
//            )
//        }
//    }
//
//    @Test
//    func zipOfZips() {
//        #expect(throws: Errors([E(0), E(1), E(2)])!) {
//            let (a: (), b: ()) = try allSucceed(
//                { throw E(0) },
//                { throw Errors([E(1), E(2)])! }
//            )
//        }
//    }
//}
