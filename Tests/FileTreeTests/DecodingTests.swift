//
//  DecodingTests.swift
//  swift-file-tree
//
//  Created by Woodrow Melling on 10/1/24.
//

import Foundation
import Testing
import Dependencies
import DependenciesTestSupport
@testable import FileTree


extension URL {
    static let resourcesFolder = Bundle.module.bundleURL.appending(component: "Contents/Resources/Resources")
}

extension Data {
    var utf8DecodedString: String {
        String(decoding: self, as: UTF8.self)
    }
}

@Suite(.dependency(\.context, .live))
struct FileSystemTests {

    @Test
    func readSimpleDirectory() async throws {
        let simpleDirectory = Directory("SimpleDirectory") {
            File("FirstFile", .plainText)
        }

        let result = try await simpleDirectory.read(from: .resourcesFolder)
        #expect(result.directoryName == "SimpleDirectory")
        #expect(result.components.data.utf8DecodedString == "This is some text\n")
        #expect(result.components.fileName == "FirstFile")
        #expect(result.components.fileType == .plainText)
    }

    @Test
    func readManyFromSimpleDirectory() async throws {
        let simpleDirectory = Directory("SimpleDirectory") {
            Many {
                File($0, .plainText)
            }
        }

        let result = try await simpleDirectory.read(from: .resourcesFolder)

        #expect(result.directoryName == "SimpleDirectory")

        let components = result.components.sorted(by: { $0.fileName < $1.fileName })

        #expect(components[0].fileName == "FirstFile")
        #expect(components[0].data.utf8DecodedString == "This is some text\n")

        #expect(components[1].fileName == "SecondFile")
        #expect(components[1].data.utf8DecodedString == "one more chunk of text\n")
    }

    @Test
    func readMyEvent() async throws {

    }

}





