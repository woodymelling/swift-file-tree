//
//  ConversionTests.swift
//  swift-file-tree
//
//  Created by Woodrow Melling on 12/3/24.
//

import Testing
@testable import FileTree
import Foundation
import Conversions

extension Tag {
    @Tag static var conversion: Self
}

@Suite(.dependency(\.fileManagerClient, .liveValue))
final class FileTreeConversionTests {
    var tempDirectoryURL: URL

    init() {
        self.tempDirectoryURL = .temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try! FileManager.default.createDirectory(at: tempDirectoryURL, withIntermediateDirectories: true)
    }

    deinit {
        try! FileManager.default.removeItem(at: tempDirectoryURL)
    }

    @Test(.tags(.fileReading, .fileWriting, .conversion))
    func testDataToStringConversionRoundTrip() throws {
        let staticFileTree = StaticFile("TestFile", "txt")
            .map(Conversions.DataToString())

        let testString = "Hello, World!"

        try staticFileTree.write(testString, to: tempDirectoryURL)
        let readString = try staticFileTree.read(from: tempDirectoryURL)

        #expect(testString == readString, "The read string should match the written string.")
    }

    @Test(.tags(.fileReading, .fileWriting, .conversion))
    func testDataToCodableConversionRoundTrip() throws {
        struct User: Codable, Equatable {
            let id: Int
            let name: String
        }

        let userFileTree = StaticFile("UserFile", "json")
            .map(.json(User.self))

        let testUser = User(id: 1, name: "Alice")

        try userFileTree.write(testUser, to: tempDirectoryURL)
        let readUser = try userFileTree.read(from: tempDirectoryURL)

        #expect(testUser == readUser, "The read user should match the written user.")
    }

}

