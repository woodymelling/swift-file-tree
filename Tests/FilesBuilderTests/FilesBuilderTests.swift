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
    func justAFile() throws {
        try withDependencies {
            $0.fileManagerClient.data = { @Sendable in
                #expect($0 == URL.applicationDirectory.appending(path: "test.txt"))
                return Data()
            }

        } operation: {
            let result = try File("test", .plainText)
                .read(from: URL.applicationDirectory)

            #expect(result == FileContent(fileName: "test", fileType: .plainText, data: Data()))
        }
    }

    @Test
    func directoryWithAFile() throws {
        try withDependencies {
            $0.fileManagerClient.data = { @Sendable in
                #expect($0 == URL.applicationDirectory.appending(path: "dir").appending(path: "test.txt"))
                return Data()
            }
        } operation: {
            let structure = Directory("dir") {
                File("test", .plainText)
            }

            let result = try structure.read(from: URL.applicationDirectory)

            #expect(
                result == DirectoryContents(
                    directoryName: "dir",
                    components: FileContent(fileName: "test", fileType: .plainText, data: Data())
                )
            )
        }
    }

    @Test
    func dirDirFile() throws {
        try withDependencies {
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

            let result = try structure.read(from: URL.applicationDirectory)

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
    func manyFile() throws {
        try withDependencies {
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

            let result = try structure.read(from: URL.applicationDirectory)

            #expect(
                result == [
                    FileContent(fileName: "file1", fileType: .plainText, data: Data()),
                    FileContent(fileName: "file2", fileType: .plainText, data: Data()),
                ]
            )
        }
    }

    @Test
    func directoryWithMultipleFiles() throws {


        try withDependencies {
            $0.fileManagerClient.data = { @Sendable in
                #expect($0 == URL.applicationDirectory.appending(path: "dir").appending(path: "test.txt"))
                return Data()
            }
        } operation: {
            let structure = Directory("dir") {
                File("test1", .plainText)
                File("test2", .plainText)
            }

            let result = try structure.read(from: URL.applicationDirectory)
            let expected: DirectoryContents<FileContent, FileContent> =  DirectoryContents(
                directoryName: "dir",
                components: (
                    FileContent(fileName: "test1", fileType: .plainText, data: Data()),
                    FileContent(fileName: "test2", fileType: .plainText, data: Data())
                )
            )

            #expect(
                result == expected
            )
        }
    }

}



