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
    func dataToStringConversionRoundTrip() throws {
        let staticFileTree = File("TestFile", "txt")
            .convert(Conversions.DataToString())

        let testString = "Hello, World!"

        try staticFileTree.write(testString, to: tempDirectoryURL)
        let readString = try staticFileTree.read(from: tempDirectoryURL)

        #expect(testString == readString, "The read string should match the written string.")
    }

    @Test(.tags(.fileReading, .fileWriting, .conversion))
    func dataToCodableConversionRoundTrip() throws {
        struct User: Codable, Equatable {
            let id: Int
            let name: String
        }

        let userFileTree = File("UserFile", "json")
            .convert(.json(User.self))

        let testUser = User(id: 1, name: "Alice")

        try userFileTree.write(testUser, to: tempDirectoryURL)
        let readUser = try userFileTree.read(from: tempDirectoryURL)

        #expect(testUser == readUser, "The read user should match the written user.")
    }

    @Test(.tags(.fileReading, .fileWriting, .many))
    func testDirectoriesWithTwoFilesRoundTrip() throws {
        let directories = Directory.Many {
            File("File1", .text)
            File("File2", .text)
        }

        let directoryContents = [
            DirectoryContent(
                directoryName: "Directory1",
                components: (
                    Data("Content 1".utf8),
                    Data("Content 2".utf8)
                )
            ),
            DirectoryContent(
                directoryName: "Directory2",
                components: (
                    Data("Content 3".utf8),
                    Data("Content 4".utf8)
                )
            )
        ]

        try $writingToEmptyDirectory.withValue(true) {
            try directories.write(directoryContents, to: tempDirectoryURL)
        }

        let readContents = try directories.read(from: tempDirectoryURL)

        #expect(directoryContents.count == readContents.count, "The number of directories read should match the number written.")

        for (writtenDir, readDir) in zip(directoryContents, readContents) {
            #expect(writtenDir.directoryName == readDir.directoryName, "Directory names should match.")

            let (writtenData1, writtenData2) = writtenDir.components
            let (readData1, readData2) = readDir.components

            #expect(writtenData1 == readData1, "Data for File1 in \(writtenDir.directoryName) should match.")
            #expect(writtenData2 == readData2, "Data for File2 in \(writtenDir.directoryName) should match.")
        }
    }

    @Test(.tags(.fileReading, .fileWriting, .conversion))
    func testFileManyMapConversionRoundTrip() throws {
        let fileTree = File.Many(withExtension: "txt").map {
            FileContentConversion {
                Conversions.DataToString()
            }
        }
//
//        let fileContentsToWrite = [
//            FileContent<String>(fileName: "File1", data: "Content 1"),
//            FileContent<String>(fileName: "File2", data: "Content 2"),
//            FileContent<String>(fileName: "File3", data: "Content 3")
//        ]
//
//        try $writingToEmptyDirectory.withValue(true) {
//            try fileTree.write(fileContentsToWrite, to: tempDirectoryURL)
//        }
//
//
//
//        let readContents = try fileTree.read(from: tempDirectoryURL)
//
//        #expect(fileContentsToWrite.count == readContents.count, "The number of files read should match the number written.")
//
//
//
//        for (written, read) in zip(fileContentsToWrite, readContents) {
//            #expect(written.fileName == read.fileName, "File names should match.")
//            #expect(written.data == read.data, "File data should match.")
//        }
    }

    @Test(.tags(.fileReading, .fileWriting, .conversion))
    func testDirectoryManyMapConversionRoundTrip() throws {

        let mappedDirectoryMany = Directory.Many {
            File("File1", "txt")
        }
            .map {
                DirectoryContentConversion {
                    Conversions.DataToString()
                }
            }

        let directoriesToWrite = [
            DirectoryContent(
                directoryName: "Dir1",
                components: "Content1"
            ),
            DirectoryContent(
                directoryName: "Dir2",
                components: "Content2"
            )
        ]

        try $writingToEmptyDirectory.withValue(true) {
            try mappedDirectoryMany.write(directoriesToWrite, to: tempDirectoryURL)
        }

        let readDirectories = try mappedDirectoryMany.read(from: tempDirectoryURL)

        // Assert
        #expect(directoriesToWrite.count == readDirectories.count, "The number of directories should match.")

        for (writtenDir, readDir) in zip(directoriesToWrite, readDirectories) {
            #expect(writtenDir.directoryName == readDir.directoryName, "Directory names should match.")
            #expect(writtenDir.components == readDir.components, "Components should match for directory \(writtenDir.directoryName).")
        }
    }
}

