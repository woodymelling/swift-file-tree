//
//  File.swift
//  swift-file-tree
//
//  Created by Woodrow Melling on 12/5/24.
//

import UniformTypeIdentifiers
import Foundation
import IssueReporting

public struct File: FileTreeComponent {
    let fileName: StaticString
    let fileType: UTFileExtension

    public init(_ fileName: StaticString, _ fileType: UTType) {
        self.fileName = fileName
        self.fileType = .utType(fileType)
    }

    public init(_ fileName: StaticString, _ fileType: FileExtension) {
        self.fileName = fileName
        self.fileType = .extension(fileType)
    }

    public func read(from url: URL) throws -> Data {
        let fileUrl = url.appendingPathComponent(fileName.description, withType: fileType)

        return try Data(contentsOf: fileUrl)
    }

    public func write(_ data: Data, to url: URL) throws {
        let fileUrl = url.appendingPathComponent(fileName.description, withType: fileType)

        return try data.write(to: fileUrl)
    }
}

extension File {
    public struct Many: FileTreeComponent {
        public typealias Content = [FileContent<Data>]
        let fileType: UTFileExtension

        public init(withExtension content: UTType) {
            self.fileType = .utType(content)
        }

        public init(withExtension content: FileExtension) {
            self.fileType = .extension(content)
        }
        public func read(from url: URL) throws -> [FileContent<Data>] {
            let paths = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: [])

            let filteredPaths = paths.filter { $0.pathExtension == self.fileType.identifier }

            return try filteredPaths.map { fileURL in

                let data = try Data(contentsOf: fileURL)
                return FileContent(fileName: fileURL.deletingPathExtension().lastPathComponent, data: data)
            }.sorted { $0.fileName < $1.fileName }
        }

        public func write(_ data: [FileContent<Data>], to url: URL) throws {
            guard writingToEmptyDirectory
            else {
                reportIssue("""
            Writing an array of files to a directory that may already have contents currently unsupported.
            
            This is because of the circumstance where a file exists in the directory, but not in the array
            It is difficult to determine if the file should be deleted, or if it exists outside of the purview of the `Files` block and should be left alone.
            
            The semantics of Many may need to be tweaked to make this determination more clear.
            
            To allow writing to the directory, use:
            
            ```
            $writingToEmptyDirectory.withValue(true) { 
                Files(withExtension: .text).write([Data(), Data(), Data()]))
            }
            ```
            
            which will naively write all the contents to the directory, and not delete anything that is already there.
            """)
                return
            }

            for fileContent in data {
                let fileURL = url.appendingPathComponent(fileContent.fileName, withType: self.fileType)
                try fileContent.data.write(to: fileURL)
            }
        }
    }
}

public struct FileContent<Content> {
    public var fileName: String
    public var data: Content

    public init(fileName: String, data: Content) {
        self.fileName = fileName
        self.data = data
    }
}

extension FileContent: Hashable where Content: Hashable {}
extension FileContent: Sendable where Content: Sendable {}
extension FileContent: Equatable where Content: Equatable {}
public extension FileContent {
    func map<NewContent>(_ transform: (Content) throws -> NewContent) rethrows -> FileContent<NewContent> {
        try FileContent<NewContent>(
            fileName: fileName,
            data: transform(self.data)
        )
    }
}
