//
//  File.swift
//  swift-file-tree
//
//  Created by Woodrow Melling on 12/5/24.
//

import Foundation
import IssueReporting

public struct File: FileTreeComponent {
    let fileName: StaticString
    let fileType: FileExtension

    public init(_ fileName: StaticString, _ fileType: FileExtension) {
        self.fileName = fileName
        self.fileType = fileType
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
        let fileType: FileExtension?

        public init() {
            self.fileType = nil
        }

        public init(withExtension content: FileExtension) {
            self.fileType = content
       }

        public func read(from url: URL) throws -> [FileContent<Data>] {
            var paths = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: [])

            if let fileType {
                paths = paths.filter { $0.pathExtension == fileType.rawValue }
            }

//            let filteredPaths = paths.filter { $0.pathExtension == self.fileType.identifier }

            return try paths.map { fileURL in

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

                let fileURL = if let fileType {
                    url.appendingPathComponent(fileContent.fileName, withType: fileType)
                } else {
                    url.appending(path: fileContent.fileName)
                }

                try fileContent.data.write(to: fileURL)
            }
        }
    }
}

public struct FileContent<Component> {
    public var fileName: String
    public var data: Component
    
    public init(fileName: String, data: Component) {
        self.fileName = fileName
        self.data = data
    }
}

extension FileContent: Hashable where Component: Hashable {}
extension FileContent: Sendable where Component: Sendable {}
extension FileContent: Equatable where Component: Equatable {}
public extension FileContent {
    func map<NewContent>(_ transform: (Component) throws -> NewContent) rethrows -> FileContent<NewContent> {
        try FileContent<NewContent>(
            fileName: fileName,
            data: transform(self.data)
        )
    }
}

