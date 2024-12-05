# FileTree

FileTree is a Swift package that provides a type-safe, declarative way to interact with file system structures.

## Features

- Declarative file system structure definition
- Type-safe file and directory representations

## Installation

Add the following to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/woodymelling/swift-file-tree", from: "0.1.0")
]
```

## Usage

```swift
import FileTree
import UniformTypeIdentifiers

let blogFileTree = FileTree {
    Directory("Blog") {
        File("About", .txt)
        Directory("Posts") {
            File.Many(withExtension: .md)
        }
    }
}
```

From here, you can:

- **Read and write raw data** from the file system, allowing you to load Markdown posts, 
  images, configurations, or any binary content.
- **Convert raw data into well-defined Swift types** to ensure your application logic remains 
  clean and type-safe. Transform text files into strings, decode JSON into models, or parse 
  custom formats into domain-specific types.
- **Render file trees in SwiftUI** using `FileTreeViewable` for a visual representation of your 
  project’s structure. Easily inspect directories and files right in your app’s UI.

This approach lets you keep your file system logic expressive yet separated from your 
business logic. You decide how much detail to expose to the rest of your application, and 
Swift File Tree takes care of bridging the gap between your on-disk data and in-memory models.

## Topics

### Essentials

- <doc:GettingStarted>  
  Learn the basics of defining a file tree and interacting with it.
  
### Components

- `File`  
- `Directory`  
- `File.Many`
- `Directory.Many`
---
```
## Usage

Here's a quick example of how to use FileTree:

```swift
import FileTree

let structure = Directory("documents") {
    File("readme", .plaintext)
    Directory("images") {
        Many { fileName in
            File(fileName, .png)
        }
    }
}

// Read the contents of the structure
let (readme, images) = try await structure.read(from: URL.documentsDirectory).components

let images: [FileContent] = images.components.0
```

## Contributing

As this is a work in progress, contributions are welcome! Please open an issue to discuss proposed changes before submitting a pull request.
