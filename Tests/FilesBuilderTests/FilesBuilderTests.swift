import Testing
@testable import FilesBuilder

@Test func example() async throws {

    let loader = Directory("") {
        File("event-info.yaml")

        File("contact-info.yaml")

        Directory("schedules") {
            Many {
                File($0)
            }
        }

        Directory("artists") {
            Many {
                File($0)
            }
        }
    }

    print(loader)


}
