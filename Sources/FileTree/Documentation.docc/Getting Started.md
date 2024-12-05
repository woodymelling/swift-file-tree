Learn how to define file system structures in your application code using **FileTree**, how to read and write raw data to the disk, convert file trees into well-defined Swift types, and render the structure using SwiftUI.

# Creating a File Tree

The primary tool for defining a file structure in your application is the `FileTree` component. You can invoke it to declaratively specify the directories and files your application needs.

Let's define a file structure suitable for a blogging application:

```swift
import SwiftFileTree
import UniformTypeIdentifiers

let blogFileTree = FileTree {
    Directory("Blog") {
        File("About", "json") 
        Directory("Posts") {
            File.Many(withExtension: .init(stringLiteral: "md"))
        }
    }
}
```

In this example:

- The `Blog` directory contains:
    - An `About` file (a `.json` file containing information about the blog).
    - A `Posts` directory, which handles multiple Markdown (`.md`) files representing individual blog posts.

This declarative approach allows you to easily visualize and manage your application's file structure,

which would look like this:
```
Blog/
├── About.json
└── Posts/
    ├── post1.md
    ├── post2.md
    ├── post3.md
    └── ...

```

# Reading and Writing from the Disk

Once you've defined your file tree, you can read from and write to the file system using the `read(from:)` and `write(_:to:)` methods.

## Reading Raw Data

To read data from the file system using raw types:

```swift
do {
    let url = URL(fileURLWithPath: "/path/to/blog")
    let content: (Data, [FileContent<Data>]) = try blogFileTree.read(from: url)
} catch {
    print("Failed to read from the file system: \(error)")
}
```

The `content` variable contains raw data matching the structure of your file tree:
- The `Data` at `/path/to/blog/About.json`
- a `[FileContent<Data>]` that holds onto the different posts. `FileContent` contains the Data that represents the text of the post, and the name of the file, represents the title of the blog post in our file structure.

## Writing Raw Data

To write raw data to the file system:

```swift
do {
    let url = URL(fileURLWithPath: "/path/to/blog")
    // Prepare your raw content matching the structure of your file tree
    let aboutData = Data("Welcome to my blog!".utf8)
    let postsData = [
        FileContent(fileName: "post1", data: Data("# First Post\nThis is my first post.".utf8)),
        FileContent(fileName: "post2", data: Data("# Second Post\nThis is my second post.".utf8))
    ]
    let content = (aboutData, postsData)
    try blogFileTree.write(content, to: url)
} catch {
    print("Failed to write to the file system: \(error)")
}
```

Ensure that the `content` you provide matches the structure and types expected by your `FileTree`:

- A tuple containing `aboutData` (`Data`) and `postsData` (`[FileContent<Data>]`).

# Converting to a Well-Defined Swift Type

Working with raw data types is functional, but it's often more convenient to work with well-defined Swift types that encapsulate your application's logic. Swift File Tree provides tools to convert file trees into custom Swift types, allowing for a clean separation between your file system logic and application logic.

## Defining Custom Data Models

First, define your custom data models that represent the content you expect from the file system:

```swift
struct Post {
    let title: String
    let body: String
}

struct About: Codable {
    let author: String
    let socialMediaLinks: [URL]
}

struct Blog {
    let about: About
    let posts: [Post]
}
```

##  Conversions

Conversions are an important concept for FileTree. They define how to convert a type `A` into another type, `B` (`A -> B`), as well as the process to convert `B -> A`. This means that when reading from the disk, we can transform the nebulous `Data` into a well defined type, but also transform the well defined type back into `Data`

There are a number of pre-defined conversions available, and you are able to define your own conversions. You can even build up complex multi step conversions by combining other `Conversion`s together. 
### Converting the About File

```swift
File("About", "txt")
    .convert(.json(Blog.About.self))
```

This converts the raw `Data` from the `About.txt` file into a `Blog.About` type. 

### Converting the Posts

For the posts, we'll convert each Markdown file into a `Post` object. You can define a custom conversion:

```swift
struct PostConversion: Conversion {

    var body: some Conversion<FileContent<Data>, Blog.Post> {
        // This converts the content of a file from `Data->String`
        FileContentConversion {
            DataToStringConversion()
        }

        // This converts FileContent<String> -> Blog.Post
        AnyConversion(
            apply: { fileContent in
                Blog.Post(title: fileContent.fileName, body: fileContent.data)
            },
            unapply: { post in
                FileContent(fileName: post.title, data: post.body)
            }
        )
    }
}
```

### Integrating Conversions into the File Tree

Update your `blogFileTree` to include the conversions:

```swift
let blogFileTree = FileTree {
    Directory("Blog") {
        File("About", "txt")
            .convert(.json(Blog.About.self))
            
        Directory("Posts") {
            File.Many(withExtension: "md")
                .map(PostConversion())
        }
    }
    .convert(
        AnyConversion(
            apply: { about, posts in
                Blog(about: about, posts: posts)
            },
            unapply: { blog in
                (blog.about, blog.posts)
            }
        )
    )
}
```

## Reading and Writing Custom Types

Now you can read from and write to the file system using your custom `Blog` type.

### Reading Data

```swift
do {
    let blog: Blog = try blogFileTree.read(from: "/path/to/blog")
    // Use blog.about and blog.posts
} catch {
    print("Failed to read blog content: \(error)")
}
```

## Writing Data

```swift
do {
    let blog = Blog(
        about: "Welcome to my blog!",
        posts: [
            Post(title: "First Post", body: "This is my first post."),
            Post(title: "Second Post", body: "This is my second post.")
        ]
    )

    try blogFileTree.write(blog, to: "/path/to/blog")
} catch {
    print("Failed to write blog content: \(error)")
}
```

By performing conversions during the read and write operations, your application logic remains clean and unaware of the details of how it is written and read from the fileSystem.

# SwiftUI

Swift File Tree integrates seamlessly with SwiftUI, allowing you to render your file structures in the UI. This is especially useful in the sidebar of a NavigationSplitView

```swift
struct ContentView: View {
    let blog: Blog

    var body: some View {
        NavigationSplitView {
            List {
                blogFileTree
                    .view(for: blog)
            }
        } detail: {
            // ...
        }
    }
}
```
