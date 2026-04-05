# JSON.swift

A lightweight, type-safe JSON handling library for Swift.

[![Swift 6.0+](https://img.shields.io/badge/Swift-6.0+-orange.svg)](https://swift.org)
[![Platforms](https://img.shields.io/badge/Platforms-macOS%20|%20iOS%20|%20tvOS%20|%20watchOS%20|%20visionOS%20|%20Linux-blue.svg)](https://swift.org)
[![License](https://img.shields.io/badge/License-Apache%202.0-green.svg)](LICENSE)

## Features

- 🎯 **Type-safe** — Strongly typed `JSON` enum with cases for every JSON type
- 🔄 **Codable** — Full `Codable`, `Sendable`, `Hashable`, and `Equatable` support
- ✨ **Literal syntax** — Write JSON naturally using Swift literals
- 🔍 **Dynamic member lookup** — Access object keys with dot syntax
- ✏️ **Mutable subscripts** — Modify JSON values in place
- 🔀 **Deep merge** — Recursively merge JSON objects
- 📐 **JSON Schema** — Type-safe JSON Schema definitions for structured output
- 📦 **Swift Package Manager** — Easy integration into any Swift project

## Installation

### Swift Package Manager

Add JSON.swift to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/rchatham/JSON.swift.git", from: "1.0.0")
]
```

Then add `"JSON"` as a dependency of your target:

```swift
targets: [
    .target(
        name: "MyApp",
        dependencies: ["JSON"]
    )
]
```

Or in Xcode: **File → Add Package Dependencies** and enter the repository URL.

## Quick Start

```swift
import JSON
```

### Creating JSON Values

Use Swift literals for natural JSON construction:

```swift
let user: JSON = [
    "name": "Alice",
    "age": 30,
    "active": true,
    "scores": [95, 87, 100],
    "address": [
        "city": "New York",
        "zip": "10001"
    ]
]
```

Or create from individual values:

```swift
let name: JSON = "Alice"
let age: JSON = 30
let pi: JSON = 3.14
let flag: JSON = true
let nothing: JSON = nil
```

### Parsing JSON

```swift
// From a JSON string
let json = try JSON(string: #"{"key": "value"}"#)

// From Data
let json = try JSON(data: jsonData)

// From any Encodable value
let json = try JSON(encoding: myStruct)
```

### Accessing Values

Use subscripts, dynamic member lookup, or value extraction properties:

```swift
// Subscript access
let city = json["address"]?["city"]?.stringValue

// Dynamic member lookup (dot syntax)
let city = json.address?.city?.stringValue

// Array access
let firstScore = json.scores?[0]?.intValue

// Value extraction
json.name?.stringValue    // String?
json.age?.intValue        // Int?
json.age?.doubleValue     // Double?
json.active?.boolValue    // Bool?
json.scores?.arrayValue   // [JSON]?
json.address?.objectValue // [String: JSON]?
json.isNull               // Bool
json.count                // Int? (array/object count)
```

### Modifying JSON

```swift
var json: JSON = ["name": "Alice"]

// Set values with subscripts
json["age"] = 30
json["tags"] = ["swift", "developer"]

// Set values with dynamic member lookup
json.email = "alice@example.com"

// Remove values
json["age"] = nil

// Modify array elements
var list: JSON = ["a", "b", "c"]
list[1] = "B"
```

### Merging

```swift
let base: JSON = [
    "settings": [
        "theme": "dark",
        "fontSize": 14
    ]
]

let overrides: JSON = [
    "settings": [
        "fontSize": 16,
        "language": "en"
    ]
]

// Deep merge — recursively merges nested objects
let merged = base.merging(overrides)
// Result: {"settings": {"theme": "dark", "fontSize": 16, "language": "en"}}

// In-place merge
var config = base
config.merge(overrides)
```

### Serialization

```swift
let json: JSON = ["name": "Alice", "age": 30]

// Pretty-printed JSON string
print(json.jsonString!)

// Compact JSON string (no whitespace)
print(json.compactJSONString!)

// Encode to Data
let data = try JSONEncoder().encode(json)
```

### Decoding to Types

```swift
struct User: Codable {
    let name: String
    let age: Int
}

let json: JSON = ["name": "Alice", "age": 30]
let user: User = try json.decode(User.self)
```

## JSON Schema

Define type-safe JSON Schemas for use with LLM providers and validation:

```swift
let schema = JSONSchema.object(
    properties: [
        "name": .string(description: "User's full name"),
        "age": .integer(description: "User's age"),
        "email": .string(description: "Email address"),
        "role": .string(description: "User role", enumValues: ["admin", "user", "guest"]),
        "tags": .array(items: .string(), description: "User tags")
    ],
    required: ["name", "email"],
    additionalProperties: false,
    description: "A user profile",
    title: "UserProfile"
)
```

### StructuredOutput Protocol

Conform to `StructuredOutput` to associate a JSON Schema with your `Codable` types:

```swift
struct Weather: Codable, StructuredOutput {
    let location: String
    let temperature: Double
    let unit: String

    static var jsonSchema: JSONSchema {
        .object(
            properties: [
                "location": .string(description: "City name"),
                "temperature": .number(description: "Temperature value"),
                "unit": .string(
                    description: "Unit of measurement",
                    enumValues: ["celsius", "fahrenheit"]
                )
            ],
            required: ["location", "temperature", "unit"],
            additionalProperties: false,
            description: "Weather information"
        )
    }
}

// Access the schema
let schema = JSONSchema.from(Weather.self)
```

## API Reference

### JSON Enum Cases

| Case | Description |
|------|-------------|
| `.string(String)` | A JSON string value |
| `.number(Double)` | A JSON number value |
| `.bool(Bool)` | A JSON boolean value |
| `.object([String: JSON])` | A JSON object (dictionary) |
| `.array([JSON])` | A JSON array |
| `.null` | A JSON null value |

### Value Extraction Properties

| Property | Type | Description |
|----------|------|-------------|
| `.stringValue` | `String?` | Extract string value |
| `.doubleValue` | `Double?` | Extract number as Double |
| `.intValue` | `Int?` | Extract number as Int |
| `.boolValue` | `Bool?` | Extract boolean value |
| `.arrayValue` | `[JSON]?` | Extract array value |
| `.objectValue` | `[String: JSON]?` | Extract object value |
| `.isNull` | `Bool` | Check if null |
| `.count` | `Int?` | Array/object element count |
| `.jsonString` | `String?` | Pretty-printed JSON string |
| `.compactJSONString` | `String?` | Compact JSON string |

### Protocol Conformances

`JSON` conforms to: `Codable`, `Sendable`, `Hashable`, `Equatable`, `CustomStringConvertible`, `CustomDebugStringConvertible`, `ExpressibleByStringLiteral`, `ExpressibleByIntegerLiteral`, `ExpressibleByFloatLiteral`, `ExpressibleByBooleanLiteral`, `ExpressibleByArrayLiteral`, `ExpressibleByDictionaryLiteral`, `ExpressibleByNilLiteral`

`JSONSchema` conforms to: `Codable`, `Sendable`, `Hashable`, `CustomStringConvertible`

## License

JSON.swift is available under the Apache License 2.0. See the [LICENSE](LICENSE) file for details.
