//
//  BuilderTests.swift
//  swift-file-tree
//
//  Created by Woodrow Melling on 3/17/25.
//

import FileTree
import Testing

struct Builder {
    func builder() {
        let result = FileTree {
            File("blah", "txt")
            File("bleh", "txt")
        }
    }
}
