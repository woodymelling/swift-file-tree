//
//  File.swift
//  swift-file-tree
//
//  Created by Woodrow Melling on 12/5/24.
//

import Foundation

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
                return try FileContent(
                    fileName: fileURL.deletingPathExtension().lastPathComponent,
                    fileType: self.fileType,
                    data: data
                )
            }.sorted { $0.fileName < $1.fileName }
        }

        public func write(_ data: [FileContent<Data>], to url: URL) throws {
//            guard writingToEmptyDirectory
//            else {
//                reportIssue("""
//            Writing an array of files to a directory that may already have contents currently unsupported.
//            
//            This is because of the circumstance where a file exists in the directory, but not in the array
//            It is difficult to determine if the file should be deleted, or if it exists outside of the purview of the `Files` block and should be left alone.
//            
//            The semantics of Many may need to be tweaked to make this determination more clear.
//            
//            To allow writing to the directory, use:
//            
//            ```
//            $writingToEmptyDirectory.withValue(true) { 
//                Files(withExtension: .text).write([Data(), Data(), Data()]))
//            }
//            ```
//            
//            which will naively write all the contents to the directory, and not delete anything that is already there.
//            """)
//                return
//            }

            for fileContent in data {

                let fileURL = if let fileType {
                    url.appendingPathComponent(fileContent.fileName, withType: fileType)
                } else {
                    url.appending(path: fileContent.fileName)
                }

                try fileContent.data.write(to: fileURL, options: [.atomic])
            }
        }
    }
}


extension File {
    public struct Optional: FileTreeReader {
        public typealias Content = Data?

        public init(_ fileName: StaticString, _ fileType: FileExtension) {
            self.fileName = fileName
            self.fileType = fileType
        }

        let fileName: StaticString
        let fileType: FileExtension

        public func read(from url: URL) throws -> Data? {
            let fileUrl = url.appendingPathComponent(fileName.description, withType: fileType)

            guard FileManager.default.fileExists(atPath: fileUrl.path())
            else { return nil }

            do {
                return try Data(contentsOf: fileUrl)
            } catch {
                throw Error(fileName: self.fileName.description, fileType: self.fileType, error: error)
            }
        }
    }
}

public struct FileContent<Component> {
    public var fileName: String
    public var fileType: FileExtension?
    public var data: Component
    
    public init(fileName: String, fileType: FileExtension?, data: Component) throws {
        try Self.validateFileName(fileName)
        self.fileName = fileName
        self.fileType = fileType
        self.data = data
    }
    
    private static func validateFileName(_ fileName: String) throws {
        guard !fileName.isEmpty else {
            throw ValidationError.emptyFileName
        }
        
        guard !fileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ValidationError.whitespaceOnlyFileName
        }
        
        guard fileName.count <= 255 else {
            throw ValidationError.fileNameTooLong(fileName.count)
        }
        
        let invalidCharacters = CharacterSet(charactersIn: "<>:\"|?*").union(.controlCharacters)
        guard fileName.rangeOfCharacter(from: invalidCharacters) == nil else {
            throw ValidationError.invalidCharacters
        }
//        
//        guard !fileName.hasSuffix(".") && !fileName.hasSuffix(" ") else {
//            throw ValidationError.invalidSuffix
//        }
//        
//        let reservedNames = ["CON", "PRN", "AUX", "NUL", "COM1", "COM2", "COM3", "COM4", "COM5", "COM6", "COM7", "COM8", "COM9", "LPT1", "LPT2", "LPT3", "LPT4", "LPT5", "LPT6", "LPT7", "LPT8", "LPT9"]
//        let nameWithoutExtension = (fileName as NSString).deletingPathExtension.uppercased()
//        guard !reservedNames.contains(nameWithoutExtension) else {
//            throw ValidationError.reservedName(fileName)
//        }
    }
    
    public enum ValidationError: Error, CustomStringConvertible {
        case emptyFileName
        case whitespaceOnlyFileName
        case fileNameTooLong(Int)
        case invalidCharacters
        case invalidSuffix
        case reservedName(String)
        
        public var description: String {
            switch self {
            case .emptyFileName:
                return "File name cannot be empty"
            case .whitespaceOnlyFileName:
                return "File name cannot contain only whitespace"
            case .fileNameTooLong(let length):
                return "File name too long (\(length) characters, maximum 255)"
            case .invalidCharacters:
                return "File name contains invalid characters (< > : \" | ? * or control characters)"
            case .invalidSuffix:
                return "File name cannot end with period or space"
            case .reservedName(let name):
                return "'\(name)' is a reserved file name"
            }
        }
    }
}

extension FileContent: Hashable where Component: Hashable {}
extension FileContent: Sendable where Component: Sendable {}
extension FileContent: Equatable where Component: Equatable {}
public extension FileContent {
    func map<NewContent>(_ transform: (Component) throws -> NewContent) throws -> FileContent<NewContent> {
        try FileContent<NewContent>(
            fileName: fileName,
            fileType: self.fileType,
            data: transform(self.data)
        )
    }
}

