# ``SwiftFileTree``

Define and interact with complex file system hierarchies in a safe, declarative manner, and integrate
them seamlessly into your Swift applications and SwiftUI interfaces.

## Overview

**SwiftFileTree** provides powerful primitives for describing your application’s file system layout, 
reading and writing files, and converting file structures into strongly-typed Swift models. At its 
core is the `FileTree` type, which lets you declare directories, files, and nested structures 
directly in code. For example, you might define a blog’s file structure like this:

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
- `FileTreeComponent`
---
```
