import Testing
import Foundation
@testable import FileTree
import Dependencies

extension Tag {
    @Tag static var fileReading: Self
}

struct FileTreeTests {
    @Test(.tags(.fileReading))
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

    @Test(.tags(.fileReading))
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

    @Test(.tags(.fileReading))
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

    @Test(.tags(.fileReading))
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
                Set(result) == [
                    FileContent(fileName: "file1", fileType: .plainText, data: Data()),
                    FileContent(fileName: "file2", fileType: .plainText, data: Data()),
                ]
            )
        }
    }



    @Test(.tags(.fileReading))
    func directoryWithMultipleFiles() async throws {
        let expectations: Verifier<URL, Void> = .init(
            items:  [
                URL.documentsDirectory.appending(path: "dir").appending(path: "test1.txt"),
                URL.documentsDirectory.appending(path: "dir").appending(path: "test2.txt"),
                URL.documentsDirectory.appending(path: "dir").appending(path: "test3.txt"),
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
                File("test3", .plainText)
            }

            let result = try await structure.read(from: URL.documentsDirectory)
            
            let expected = DirectoryContents(
                directoryName: "dir",
                components: (
                    FileContent(fileName: "test1", fileType: .plainText, data: Data()),
                    FileContent(fileName: "test2", fileType: .plainText, data: Data()),
                    FileContent(fileName: "test3", fileType: .plainText, data: Data())

                )
            )

            #expect(result.components == expected.components)
        }
    }

    @Test(.tags(.fileReading))
    func nestedDirectories() async throws {
        let expectations: Verifier<URL, Void> = .init(
            items:  [
                URL.documentsDirectory.appending(path: "dir").appending(path: "test1.txt"),
                URL.documentsDirectory.appending(path: "dir").appending(path: "child").appending(path: "test2.txt"),
                URL.documentsDirectory.appending(path: "dir").appending(path: "child").appending(path: "test3.txt")
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
                Directory("child") {
                    File("test2", .plainText)
                    File("test3", .plainText)
                }
            }

            let result = try await structure.read(from: URL.documentsDirectory)

            let expected = DirectoryContents(
                directoryName: "dir",
                components: (
                    FileContent(fileName: "test1", fileType: .plainText, data: Data()),
                    DirectoryContents(
                        directoryName: "child",
                        components: (
                            FileContent(fileName: "test2", fileType: .plainText, data: Data()),
                            FileContent(fileName: "test3", fileType: .plainText, data: Data())
                        )
                    )
                )
            )

            #expect(
                result.components.0 == expected.components.0
            )

            #expect(
                result.components.1.components == expected.components.1.components
            )

            #expect(
                result.directoryName == expected.directoryName
            )
        }
    }

    @Test(.tags(.fileReading)) func realWorldStructure() async throws {

        let eventURL = URL.documentsDirectory.appending(path: "2024")
        let speakersURL = URL.documentsDirectory.appending(path: "2024").appending(path: "speakers")
        let schedulesURL = URL.documentsDirectory.appending(path: "2024").appending(path: "schedules")

        try await withDependencies {
            $0.fileManagerClient.data = { @Sendable url in
                switch url {
                case eventURL.appending(path: "event-info.yml"): return "event-info".data(using: .utf8)!
                case speakersURL.appending(path: "Sean MacLeod.txt"): return Data()
                case speakersURL.appending(path: "Lisa Hill.txt"): return Data()
                case speakersURL.appending(path: "Stephanie Taylor.txt"): return Data()
                default:
                    #expect(Bool(false), "Asked for \(url)")
                    return Data()

                }
            }

            $0.fileManagerClient.contentsOfDirectory = { @Sendable url in
                switch url {
                case speakersURL:
                    return [
                        speakersURL.appending(path: "Sean MacLeod.txt"),
                        speakersURL.appending(path: "Lisa Hill.txt"),
                        speakersURL.appending(path: "Stephanie Taylor.txt")
                    ]
                case schedulesURL:
                    return []
                default:
                    #expect(Bool(false), "Asked for \(url)")
                    return []
                }
            }

            $0.fileManagerClient.fileExists = { @Sendable url, _ in
                switch url {
                case eventURL.appending(path: "contact-info.yml"): return false
                case speakersURL: return true
                case schedulesURL: return false
                default:
                    #expect(Bool(false), "Asked for \(url)")
                    return false
                }
            }
        } operation: {
            let structure = Directory("2024") {
                File("event-info", .yaml)

                OptionalFile("contact-info", .yaml)

                OptionalDirectory("schedules") {
                    Many {
                        File($0, .yaml)
                    }
                }

                Directory("speakers") {
                    Many {
                        File($0, .plainText)
                    }
                }
            }

            let result = try await structure.read(from: URL.documentsDirectory)

            let (eventInfo, contactInfo, schedules, speakers) = result.components

            #expect(
                eventInfo == FileContent(
                    fileName: "event-info",
                    fileType: .yaml,
                    data: "event-info".data(using: .utf8)!
                )
            )

            #expect(contactInfo == nil)

            #expect(speakers.directoryName ==  "speakers")

            #expect(schedules == nil)

            #expect(Set(speakers.components) == [
                FileContent(fileName: "Sean MacLeod", fileType: .plainText, data: Data()),
                FileContent(fileName: "Lisa Hill", fileType: .plainText, data: Data()),
                FileContent(fileName: "Stephanie Taylor", fileType: .plainText, data: Data()),
            ])

        }

    }
}




actor Verifier<T: Sendable & Hashable, U> {
    var items: [T : U]

    init(items: [T : U]) {
        self.items = items
    }

    func seen(
        _ item: T,
         sourceLocation: SourceLocation = #_sourceLocation
    ) -> U {
        #expect(items.keys.contains(item), sourceLocation: sourceLocation)
        return items[item]!
    }
}

extension Verifier where U == Void {
    init(items: Set<T>) {
        var temp: [T: U] = [:]
        for item in items {
            temp[item] = ()
        }
        self.init(items: temp)
    }

    func seen(_ item: T, sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(items.keys.contains(item), sourceLocation: sourceLocation)
    }
}

