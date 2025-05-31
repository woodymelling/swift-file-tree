//
//  File.swift
//  swift-file-tree
//
//  Created by Woodrow Melling on 12/5/24.
//

import Foundation
import IssueReporting

public struct File: FileTreeReader, Sendable {
    let fileName: StaticString
    let fileType: FileExtension

    public init(_ fileName: StaticString, _ fileType: FileExtension) {
        self.fileName = fileName
        self.fileType = fileType
    }

    struct Error: Swift.Error {
        
        let fileName: String
        let fileType: FileExtension?
        let error: Swift.Error

        init(file: File, error: Error) {
            self.fileName = file.fileName.description
            self.fileType = file.fileType
            self.error = error
        }

        init(fileName: String, fileType: FileExtension?, error: Swift.Error) {
            self.fileName = fileName
            self.fileType = fileType
            self.error = error
        }
    }

    public func read(from url: URL) throws -> Data {
        let fileUrl = url.appendingPathComponent(fileName.description, withType: fileType)

        do {
            return try Data(contentsOf: fileUrl)
        } catch {
            throw Error(fileName: self.fileName.description, fileType: self.fileType, error: error)
        }
    }

    public func write(_ data: Data, to url: URL) throws {
        let fileUrl = url.appendingPathComponent(fileName.description, withType: fileType)

        return try data.write(to: fileUrl)
    }
}

extension File {
    public struct Many: FileTreeReader {
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
                return FileContent(
                    fileName: fileURL.deletingPathExtension().lastPathComponent,
                    fileType: self.fileType,
                    data: data
                )
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
    public var fileType: FileExtension?
    public var data: Component
    
    public init(fileName: String, fileType: FileExtension?, data: Component) {
        self.fileName = fileName
        self.fileType = fileType
        self.data = data
    }
}

extension FileContent: Hashable where Component: Hashable {}
extension FileContent: Sendable where Component: Sendable {}
extension FileContent: Equatable where Component: Equatable {}
public extension FileContent {
    func map<NewContent>(_ transform: (Component) throws -> NewContent) rethrows -> FileContent<NewContent> {
        do {
            return try FileContent<NewContent>(
                fileName: fileName,
                fileType: self.fileType,
                data: transform(self.data)
            )
        } catch {
            throw File.Error(
                fileName: self.fileName,
                fileType: self.fileType,
                error: error
            )
        }
    }
}

