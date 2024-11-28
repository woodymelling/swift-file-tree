//
//  FileManagerClient.swift
//  FilesBuilder
//
//  Created by Woodrow Melling on 9/30/24.
//

import DependenciesMacros
import Dependencies
import Foundation

// - MARK: FileManageClient
@DependencyClient
public struct FileManagerClient: Sendable {
    public var data: @Sendable (_ contentsOf: URL) throws -> Data
    public var contentsOfDirectory: @Sendable (_ atPath: URL) throws -> [URL]
    public var fileExists: @Sendable (_ atPath: URL) -> Bool = { _ in false }
    public var writeData: @Sendable (_ data: Data, _ to: URL) throws -> Void
    public var createDirectory: @Sendable (_ at: URL, _ withIntermediateDirectories: Bool) throws -> Void
    public var removeItem: @Sendable (_ at: URL) throws -> Void
}

extension FileManagerClient: DependencyKey {
    public static let testValue: FileManagerClient = FileManagerClient()
    public static let liveValue: FileManagerClient = FileManagerClient(
        data: {
            try Data(contentsOf: $0)
        },
        contentsOfDirectory: {
            try FileManager.default.contentsOfDirectory(at: $0, includingPropertiesForKeys: [])
        },
        fileExists: {
            FileManager.default.fileExists(atPath: $0.path)
        },
        writeData: { data, url in
            try data.write(to: url)
        },
        createDirectory: { url, createIntermediates in
            try FileManager.default.createDirectory(
                at: url,
                withIntermediateDirectories: createIntermediates,
                attributes: nil
            )
        },
        removeItem: { url in
            try FileManager.default.removeItem(at: url)
        }
    )
}

extension DependencyValues {
    public var fileManagerClient: FileManagerClient {
        get { self[FileManagerClient.self] }
        set { self[FileManagerClient.self] = newValue }
    }
}
