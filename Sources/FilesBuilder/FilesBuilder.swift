// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation
import SwiftUI


@resultBuilder
struct FileSystemBuilder {
    public static func buildBlock<each Content>(_ content: repeat each Content) -> TupleFileSystemComponent<(repeat each Content)> where repeat each Content: FileSystemComponent {
            return TupleFileSystemComponent((repeat each content))
        }
}


struct TupleFileSystemComponent<T> : FileSystemComponent {

    public var value: T
    @inlinable public init(_ value: T) { self.value = value }

//
//    /// The type of view representing the body of this view.
//    ///
//    /// When you create a custom view, Swift infers this type from your
//    /// implementation of the required ``View/body-swift.property`` property.
//    @available(iOS 13.0, tvOS 13.0, watchOS 6.0, macOS 10.15, *)
//    public typealias Body = Never
//
//    var body: Never
}

protocol FileSystemComponent {
//    associatedtype Body
//    @FileLoaderBuilder var body: Self.Body { get }

}

struct FileDescriptor {
    var fileName: String
    var data: Data
}

struct File: FileSystemComponent {
    let path: String

    init(_ path: String) {
        self.path = path
    }
}

struct Directory<Content: FileSystemComponent>: FileSystemComponent {
    let path: String

    init(_ path: String, @FileSystemBuilder content: () -> Content) {
        self.path = path
    }
}

struct Many: FileSystemComponent {
    var content: (String) -> FileSystemComponent

    init(@FileSystemBuilder _ content: @escaping (String) -> FileSystemComponent) {
        self.content = content
    }
}

// Usage example:



/*
 struct FileLoader {
     var body: some FileLoader {
         File("event-info.yaml") {
             EventInfoParser()
         }

         File("contact-info.yaml") {
             ContactInfoParser()
         }

         Directory("schedules") {
             ForEach { fileName in
                 ScheduleParser()
             }
         }

         Directory("artists") {
             ForEach { fileName in
                 ArtistParser()
             }
         }

     }
 }

 */
