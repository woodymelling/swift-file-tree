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
        let fileTree = StaticFile("TestFile", "txt")
        let testData = Data("Hello, World!".utf8)

        try fileTree.write(testData, to: tempDirectoryURL)
        let readData = try fileTree.read(from: tempDirectoryURL)

        #expect(testData == readData)
    }

    @Test(.tags(.fileReading, .fileWriting))
    func fileRoundTrip() throws {
        let fileTree = File("DynamicTestFile", "txt")
        let testFileContent = FileContent(fileName: "DynamicTestFile", data: Data("Dynamic Content".utf8))

        try fileTree.write(testFileContent, to: tempDirectoryURL)
        let readContent = try fileTree.read(from: tempDirectoryURL)

        #expect(testFileContent.fileName == readContent.fileName, "File names should match.")
        #expect(testFileContent.data == readContent.data, "The read data should match the written data.")
    }

    @Test(.tags(.fileReading, .fileWriting))
    func staticDirectoryRoundTrip() throws {
        let fileTree = StaticDirectory("TestDirectory") {
            StaticFile("NestedFile", "txt")
        }
        let nestedData = Data("Nested Hello!".utf8)

        try fileTree.write(nestedData, to: tempDirectoryURL)
        let readData = try fileTree.read(from: tempDirectoryURL)

        #expect(nestedData == readData, "The read data from nested file should match the written data.")
    }
//
    @Test(.tags(.fileReading, .fileWriting))
    func directoryRoundTrip() throws {
        let fileTree = Directory("DynamicTestDirectory") {
            File("NestedDynamicFile", "txt")
        }

        let nestedContent = FileContent(fileName: "NestedDynamicFile", data: Data("Nested Dynamic Content".utf8))
        let directoryContents = DirectoryContents(directoryName: "DynamicTestDirectory", components: nestedContent)

        try fileTree.write(directoryContents, to: tempDirectoryURL)
        let readContents = try fileTree.read(from: tempDirectoryURL)

        #expect(nestedContent.fileName == readContents.components.fileName, "Nested file names should match.")
        #expect(nestedContent.data == readContents.components.data, "The nested data should match.")
    }

    @Test(.tags(.fileReading, .fileWriting, .many))
    func testManyFilesRoundTrip() throws {
        let fileTree = Many { fileName in
            File(fileName, "txt")
        }

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