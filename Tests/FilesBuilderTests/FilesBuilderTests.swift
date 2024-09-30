import Testing
import Foundation
@testable import FilesBuilder
import Dependencies

@Test func example() async throws {

    let loader = Directory("") {
        File("event-info", .yaml)

        File("contact-info", .yaml)

        Directory("schedules") {
            Many {
                File($0, .yaml)
            }
        }

        Directory("artists") {
            Many {
                File($0, .markdown)
            }
        }
    }

}


struct FileTests {
    @Test
    func justAFile() async throws {
        try await withDependencies {
            $0.fileManagerClient.data = { @Sendable in
                #expect($0 == URL.applicationDirectory.appending(path: "test.txt"))
                return Data()
            }

        } operation: {
            let result = try await File("test", .plainText)
                .read(from: URL.applicationDirectory)

            #expect(result == FileContent(fileName: "test", fileType: .plainText, data: Data()))
        }
    }

    @Test
    func directoryWithAFile() async throws {
        try await withDependencies {
            $0.fileManagerClient.data = { @Sendable in
                #expect($0 == URL.applicationDirectory.appending(path: "dir").appending(path: "test.txt"))
                return Data()
            }
        } operation: {
            let structure = Directory("dir") {
                File("test", .plainText)
            }

            let result = try await structure.read(from: URL.applicationDirectory)

            #expect(
                result == DirectoryContents(
                    directoryName: "dir",
                    components: FileContent(fileName: "test", fileType: .plainText, data: Data())
                )
            )
        }
    }

    @Test
    func dirDirFile() async throws {
        try await withDependencies {
            $0.fileManagerClient.data = { @Sendable in
                #expect($0 == URL.applicationDirectory
                    .appending(path: "dir")
                    .appendingPathComponent("dir2")
                    .appending(path: "test.txt")
                )

                return Data()
            }
        } operation: {
            let structure = Directory("dir") {
                Directory("dir2") {
                    File("test", .plainText)
                }
            }

            let result = try await structure.read(from: URL.applicationDirectory)

            #expect(
                result == DirectoryContents(
                    directoryName: "dir",
                    components: DirectoryContents(
                        directoryName: "dir2",
                        components: FileContent(fileName: "test", fileType: .plainText, data: Data())
                    )
                )
            )
        }
    }

    @Test
    func manyFile() async throws {
        try await withDependencies {
            $0.fileManagerClient.contentsOfDirectory = { @Sendable url in
                return [
                    url.appendingPathComponent("file1", conformingTo: .plainText),
                    url.appendingPathComponent("file2", conformingTo: .plainText),
                ]
            }


            $0.fileManagerClient.data = { @Sendable _ in
                return Data()
            }
        } operation: {
            let structure = Many {
                File($0, .plainText)
            }

            let result = try await structure.read(from: URL.applicationDirectory)

            #expect(
                result == [
                    FileContent(fileName: "file1", fileType: .plainText, data: Data()),
                    FileContent(fileName: "file2", fileType: .plainText, data: Data()),
                ]
            )
        }
    }

    actor Verifier<T: Sendable & Hashable> {
        var items: Set<T>

        init(items: Set<T>) {
            self.items = items
        }

        func seen(_ item: T) {
            #expect(items.contains(item))
        }
    }

    @Test
    func directoryWithMultipleFiles() async throws {
        let expectations: Verifier<URL> = .init(
            items:  [
                URL.documentsDirectory.appending(path: "dir").appending(path: "test1.txt"),
                URL.documentsDirectory.appending(path: "dir").appending(path: "test2.txt")
            ]
        )

        try await withDependencies {
            $0.fileManagerClient.data = { @Sendable in
                await expectations.seen($0)
                return Data()
            }
        } operation: {
            let structure = Directory("dir") {
                File("test1", .plainText)
                File("test2", .plainText)
            }

            let result = try await structure.read(from: URL.documentsDirectory)
            
            let expected: DirectoryContents<(FileContent, FileContent)> =  DirectoryContents(
                directoryName: "dir",
                components: (
                    FileContent(fileName: "test1", fileType: .plainText, data: Data()),
                    FileContent(fileName: "test2", fileType: .plainText, data: Data())
                )
            )

            #expect(
                result.components == expected.components
            )

            #expect(
                result.directoryName == expected.directoryName
            )
        }
    }

}



