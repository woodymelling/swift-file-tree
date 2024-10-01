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
struct FileManagerClient: Sendable {
    var data: @Sendable (_ contentsOf: URL) async throws -> Data
    var contentsOfDirectory: @Sendable (_ atPath: URL) throws -> [URL]
    var fileExists: @Sendable (_ atPath: URL, _ isDirectory: Bool) -> Bool = { _, _ in false }
}

extension FileManagerClient: TestDependencyKey {
    static let testValue: FileManagerClient = FileManagerClient()
}

extension DependencyValues {
    var fileManagerClient: FileManagerClient {
        get { self[FileManagerClient.self] }
        set { self[FileManagerClient.self] = newValue }
    }
}
