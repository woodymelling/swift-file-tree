//
//  RoundTripTests.swift
//  swift-file-tree
//
//  Created by Woodrow Melling on 12/3/24.
//

import Testing
import Foundation
import UniformTypeIdentifiers
import DependenciesTestSupport

@testable import FileTree

extension Tag {
    @Tag static var fileReading: Self
    @Tag static var fileWriting: Self
    @Tag static var many: Self
}

@Suite(.dependency(\.fileManagerClient, .liveValue))
final class FileTreeTests {
    var tempDirectoryURL: URL

    init() {
        self.tempDirectoryURL = .temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try! FileManager.default.createDirectory(at: tempDirectoryURL, withIntermediateDirectories: true)
    }

    deinit {
        try! FileManager.default.removeItem(at: tempDirectoryURL)
    }

    @Test(.tags(.fileReading, .fileWriting))
    func staticFileRoundTrip() throws {
        let fileTree = File("TestFile", "txt")
        let testData = Data("Hello, World!".utf8)

        try fileTree.write(testData, to: tempDirectoryURL)
        let readData = try fileTree.read(from: tempDirectoryURL)

        #expect(testData == readData)
    }


    @Test(.tags(.fileReading, .fileWriting))
    func staticDirectoryRoundTrip() throws {
        let fileTree = Directory("TestDirectory") {
            File("NestedFile", "txt")
        }
        let nestedData = Data("Nested Hello!".utf8)

        try fileTree.write(nestedData, to: tempDirectoryURL)
        let readData = try fileTree.read(from: tempDirectoryURL)

        #expect(nestedData == readData, "The read data from nested file should match the written data.")
    }

    @Test(.tags(.fileReading, .fileReading, .many))
    func testFilesRoundTrip() throws {
        let fileTree = File.Many(withExtension: "txt")

        let fileContents = [
            FileContent(fileName: "File1", data: Data("Content 1".utf8)),
            FileContent(fileName: "File2", data: Data("Content 2".utf8)),
            FileContent(fileName: "File3", data: Data("Content 3".utf8))
        ]

        try $writingToEmptyDirectory.withValue(true) {
            try fileTree.write(fileContents, to: tempDirectoryURL)
        }

        let readContents = try fileTree.read(from: tempDirectoryURL)

        #expect(fileContents.count == readContents.count, "The number of files read should match the number written.")

        for (written, read) in zip(fileContents, readContents) {
            #expect(written.fileName == read.fileName, "File names should match.")
            #expect(written.data == read.data, "File data should match.")
        }
    }
}
