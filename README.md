# FileTree

FileTree is a Swift package that provides a type-safe, declarative way to interact with file system structures.

**⚠️ WORK IN PROGRESS ⚠️**

This package is currently under active development. APIs are undocumented and may change without notice.

## Features

- Declarative file system structure definition
- Type-safe file and directory representations
- Asynchronous file reading operations

## Installation

Add the following to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/yourusername/FileTree.git", branch: "develop")
]
```

## Usage

Here's a quick example of how to use FileTree:

```swift
import FileTree

let structure = Directory("documents") {
    File("readme.md", .markdown)
    Directory("images") {
        File("logo.png", .png)
    }
}

// Read the contents of the structure
let contents = try await structure.read(from: URL.documentsDirectory)

// Access file contents
let readmeContent = contents.components.0
let logoContent = contents.components.1.components.0
```

## Contributing

As this is a work in progress, contributions are welcome! Please open an issue to discuss proposed changes before submitting a pull request.
