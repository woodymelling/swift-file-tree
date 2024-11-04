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
    public var data: @Sendable (_ contentsOf: URL) async throws -> Data
    public var contentsOfDirectory: @Sendable (_ atPath: URL) throws -> [URL]
    public var fileExists: @Sendable (_ atPath: URL) -> Bool = { _ in false }
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
            FileManager.default.fileExists(atPath: $0.absoluteString)
        }
    )
}

extension DependencyValues {
    public var fileManagerClient: FileManagerClient {
        get { self[FileManagerClient.self] }
        set { self[FileManagerClient.self] = newValue }
    }
}
