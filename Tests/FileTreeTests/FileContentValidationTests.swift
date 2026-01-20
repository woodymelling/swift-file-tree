//
//  FileContentValidationTests.swift
//  swift-file-tree
//
//  Created by Claude Code on 8/16/25.
//

import Testing
@testable import FileTree
import Foundation

final class FileContentValidationTests {
    
    @Test func validFileNameShouldSucceed() throws {
        let validNames = [
            "document.txt",
            "my-file",
            "file_with_underscores",
            "file123",
            "simple",
            "a"
        ]
        
        for fileName in validNames {
            #expect(throws: Never.self) {
                try FileContent(fileName: fileName, fileType: nil, data: Data())
            }
        }
    }
    
    @Test func emptyFileNameShouldThrow() throws {
        #expect(throws: FileContent<Data>.ValidationError.emptyFileName) {
            try FileContent(fileName: "", fileType: nil, data: Data())
        }
    }
    
    @Test func whitespaceOnlyFileNameShouldThrow() throws {
        let whitespaceNames = ["   ", "\t", "\n", " \t \n "]
        
        for fileName in whitespaceNames {
            #expect(throws: FileContent<Data>.ValidationError.whitespaceOnlyFileName) {
                try FileContent(fileName: fileName, fileType: nil, data: Data())
            }
        }
    }
    
    @Test func tooLongFileNameShouldThrow() throws {
        let longName = String(repeating: "a", count: 256)
        
        #expect(throws: FileContent<Data>.ValidationError.fileNameTooLong) {
            try FileContent(fileName: longName, fileType: nil, data: Data())
        }
    }
    
    @Test func invalidCharactersShouldThrow() throws {
        let invalidNames = ["file<name", "file>name", "file:name", "file\"name", "file|name", "file?name", "file*name", "file\u{0001}name"]
        
        for fileName in invalidNames {
            #expect(throws: FileContent<Data>.ValidationError.invalidCharacters) {
                try FileContent(fileName: fileName, fileType: nil, data: Data())
            }
        }
    }
    
    @Test func invalidSuffixShouldThrow() throws {
        let invalidSuffixes = ["filename.", "filename ", "test. ", "name.."]
        
        for fileName in invalidSuffixes {
            #expect(throws: FileContent<Data>.ValidationError.invalidSuffix) {
                try FileContent(fileName: fileName, fileType: nil, data: Data())
            }
        }
    }
    
    @Test func reservedNamesShouldThrow() throws {
        let reservedNames = ["CON", "PRN", "AUX", "NUL", "COM1", "LPT1", "con", "prn.txt"]
        
        for fileName in reservedNames {
            #expect(throws: FileContent<Data>.ValidationError.reservedName) {
                try FileContent(fileName: fileName, fileType: nil, data: Data())
            }
        }
    }
    
    @Test func validationErrorDescriptions() throws {
        let errors: [FileContent<Data>.ValidationError] = [
            .emptyFileName,
            .whitespaceOnlyFileName,
            .fileNameTooLong(300),
            .invalidCharacters,
            .invalidSuffix,
            .reservedName("CON")
        ]
        
        for error in errors {
            #expect(!error.description.isEmpty)
        }
    }
}