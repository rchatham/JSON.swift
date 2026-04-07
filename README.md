# JSON.swift

A production-quality Swift JSON library with type-safe schema definition, macro-driven conformance synthesis, rich validation, and schema inference.

## Requirements

- Swift 5.9+
- macOS 12+ · iOS 15+ · watchOS 8+ · tvOS 15+ · visionOS 1+

## Installation

Add the package to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/reidchatham/JSON.swift", from: "1.0.0"),
],
targets: [
    .target(name: "MyTarget", dependencies: [
        .product(name: "JSON", package: "JSON.swift"),
    ]),
]
```

---

## Quick Start

### Parsing and reading

```swift
import JSON

// Parse from a string
let json = try JSON(string: #"{"name":"Alice","age":30,"active":true}"#)

// Dynamic member lookup
print(json.name?.stringValue)   // Optional("Alice")

// Subscript
print(json["age"]?.intValue)    // Optional(30)

// Dot-path key-path subscript
let city = json[keyPath: "address.city"]  // → nil if missing

// Throwing access
let name = try json.value(forKey: "name") // throws JSONError.keyNotFound if missing
```

### Constructing JSON

```swift
// From literals
let json: JSON = [
    "name":   "Bob",
    "scores": [98, 85, 91],
    "active": true,
]

// From any Encodable value
struct Point: Encodable { let x: Double; let y: Double }
let json = try JSON(encoding: Point(x: 1, y: 2))
// → .object(["x": .number(1.0), "y": .number(2.0)])

// From JSONSerialization-style Any
let dict: [String: Any] = ["count": 3, "flag": true]
let json = try JSON(dict)
```

### Serialization

```swift
// Pretty-printed string (default)
let pretty = json.jsonString

// Custom formatting
let compact = json.jsonString(formatting: [])          // no whitespace
let sorted  = json.jsonString(formatting: .sortedKeys) // sorted, no indent

// Raw Data (avoids String intermediate)
let data = json.jsonData   // Data?
```

### Mutating

```swift
var json: JSON = ["role": "user"]

// Subscript write
json["role"] = "admin"

// Key-path write (creates nested objects as needed)
json[keyPath: "settings.theme"] = "dark"

// Merge two objects (patch wins on conflict)
let base: JSON  = ["name": "Alice", "role": "user"]
let patch: JSON = ["role": "admin", "active": true]
let merged = base.merging(patch)
// → ["name": "Alice", "role": "admin", "active": true]
```

### Iteration

```swift
let json: JSON = [1, 2, 3]

// JSON conforms to Sequence — iterate arrays directly
for item in json {
    print(item.intValue ?? 0)
}

// Or use Array/map/filter/etc.
let doubles = json.compactMap(\.doubleValue)
```

---

## JSONSchema

Define the shape of JSON values for validation, LLM structured output, and documentation.

### Factory methods

```swift
// Primitives
JSONSchema.string()
JSONSchema.string(description: "User's name", minLength: 1, maxLength: 100)
JSONSchema.string(enumValues: ["admin", "user", "guest"])
JSONSchema.string(pattern: "^[A-Z][a-z]+$")

JSONSchema.number(minimum: 0, maximum: 1)
JSONSchema.integer(minimum: 1, exclusiveMaximum: 100)
JSONSchema.boolean()
JSONSchema.null()

// Array
JSONSchema.array(items: .string(), minItems: 1, maxItems: 10, uniqueItems: true)

// Object
JSONSchema.object(
    properties: [
        "name":  .string(description: "Full name"),
        "age":   .integer(minimum: 0),
        "email": .string().nullable,   // nullable shorthand
    ],
    required: ["name", "age"],
    additionalProperties: false
)

// Composition
JSONSchema.anyOf([.string(), .null()])   // or: .string().nullable
JSONSchema.oneOf([.string(), .integer()])
JSONSchema.allOf([schemaA, schemaB])
```

### Three ways to build object schemas

**Option A — Direct factory (concise for simple schemas):**

```swift
let schema = JSONSchema.object(
    properties: ["name": .string(), "age": .integer()],
    required: ["name", "age"]
)
```

**Option B — `@resultBuilder` DSL (declarative, SwiftUI-style):**

```swift
let schema = JSONSchema.build(title: "Person") {
    JSONSchemaProperty.string("name", description: "Full name")
    JSONSchemaProperty.integer("age", minimum: 0)
    JSONSchemaProperty.string("email", required: false, minLength: 5)
}
```

**Option C — `FluentSchemaBuilder` (true method chaining):**

```swift
let schema = FluentSchemaBuilder()
    .string("name", description: "Full name")
    .integer("age", minimum: 0)
    .string("email", required: false)
    .array("tags", items: .string(), minItems: 1)
    .build(title: "Person")
```

**Option D — `SchemaBuilder` struct (imperative):**

```swift
var builder = SchemaBuilder()
builder.string("name")
builder.integer("age")
let schema = builder.build(title: "Person")
```

---

## Validation

```swift
let schema = JSONSchema.object(
    properties: ["score": .number(minimum: 0, maximum: 100)],
    required: ["score"],
    additionalProperties: false
)

let valid: JSON   = ["score": 85]
let invalid: JSON = ["score": 150, "extra": "field"]

// Bool check
valid.isValid(against: schema)    // true
invalid.isValid(against: schema)  // false

// Collect all errors
let result = invalid.validationResult(against: schema)
for error in result.errors {
    print("\(error.path): \(error.reason)")
    // root: value 150.0 is greater than maximum 100.0
    // root: additional property 'extra' is not allowed
}

// Throw on first error
try valid.validate(against: schema)   // no throw
try invalid.validate(against: schema) // throws ValidationError

// Schema-side equivalents
try schema.validate(invalid)
schema.isValid(valid)
schema.validationResult(for: invalid)
```

### Supported constraints

| Category | Keywords |
|---|---|
| Type | `type` (string/number/integer/boolean/null/array/object) |
| String | `minLength`, `maxLength`, `pattern`, `enum` |
| Number | `minimum`, `maximum`, `exclusiveMinimum`, `exclusiveMaximum` |
| Array | `items`, `minItems`, `maxItems`, `uniqueItems` |
| Object | `properties`, `required`, `additionalProperties` |
| Composition | `anyOf`, `oneOf`, `allOf` |

---

## JSONConvertible Protocol

Types that describe their own schema conform to `JSONConvertible`:

```swift
struct WeatherCard: JSONConvertible {
    let location: String
    let temperature: Double
    let conditions: String?

    static var jsonSchema: JSONSchema {
        .object(
            properties: [
                "location":    .string(description: "City name"),
                "temperature": .number(description: "Degrees Celsius"),
                "conditions":  .string(description: "Weather conditions"),
            ],
            required: ["location", "temperature"],
            additionalProperties: false
        )
    }
}

// Decode from string or data
let card = try WeatherCard.decode(from: jsonString)
let card = try WeatherCard.decode(from: data)

// Get schema
let schema = WeatherCard.jsonSchema
let schema = JSONSchema.from(WeatherCard.self)
```

---

## `@JSONSchema` Macro

Automatically synthesize `JSONConvertible` conformance from stored properties:

```swift
@JSONSchema
struct Person: Codable {
    let name: String
    let age: Int
    let email: String?       // optional → excluded from required[]

    enum Status: String, Codable { case active, inactive }
    let status: Status       // → .string(enumValues: ["active", "inactive"])
}

// The macro generates:
extension Person: JSONConvertible {
    public static var jsonSchema: JSONSchema {
        .object(
            properties: [
                "name":   .string(),
                "age":    .integer(),
                "email":  .string(),
                "status": .string(enumValues: ["active", "inactive"]),
            ],
            required: ["name", "age", "status"],
            additionalProperties: false
        )
    }
}
```

### Type mapping table

| Swift Type | JSON Schema |
|---|---|
| `String` | `.string()` |
| `Int`, `Int8` … `Int64`, `UInt` … | `.integer()` |
| `Double`, `Float`, `CGFloat`, `Decimal` | `.number()` |
| `Bool` | `.boolean()` |
| `Date` | `.string(description: "ISO 8601 date-time")` |
| `URL` | `.string(description: "URL")` |
| `UUID` | `.string(description: "UUID")` |
| `[Element]` | `.array(items: <element schema>)` |
| `[String: Value]` | `.object(additionalProperties: true)` |
| `T?` / `Optional<T>` | Same schema as `T`, excluded from `required` |
| `enum Foo: String` (nested) | `.string(enumValues: [...])` |
| Any other named type | `.from(TypeName.self)` |

The macro respects `CodingKeys` — encoded string keys are used as JSON property names:

```swift
@JSONSchema
struct ApiResponse: Codable {
    let userId: Int
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case userId    = "user_id"
        case createdAt = "created_at"
    }
}
// → properties: ["user_id": .integer(), "created_at": .string(description: "ISO 8601 date-time")]
```

The macro must be applied to a `struct`. Applying it to a `class`, `enum`, or `actor` produces a compile-time error.

---

## Schema Inference

Derive a schema from any existing JSON value:

```swift
let json: JSON = ["name": "Alice", "age": 30, "scores": [98, 85]]
let schema = json.inferredSchema()
// → .object(
//       properties: [
//           "name":   .string(),
//           "age":    .integer(),
//           "scores": .array(items: .integer())
//       ],
//       required: ["age", "name", "scores"]
//   )

// The source value always passes the schema it produced
json.isValid(against: schema) // true

// Static convenience
let schema = JSONSchema.infer(from: json)
```

---

## API Summary

### `JSON`

| API | Description |
|---|---|
| `init(string:)` | Parse from a JSON string |
| `init(data:)` | Decode from raw `Data` |
| `init(_ value: Any)` | Bridge from `JSONSerialization`-style `Any` |
| `init(encoding:)` | Encode any `Encodable` to `JSON` |
| `jsonString` | Pretty-printed, sorted-keys string |
| `jsonString(formatting:)` | String with custom output formatting |
| `jsonData` | Raw UTF-8 `Data` (no String intermediate) |
| `stringValue` / `doubleValue` / `intValue` / `boolValue` | Type-safe optional accessors |
| `truncatedIntValue` | Integer value, truncating fractional part |
| `arrayValue` / `objectValue` | Collection accessors |
| `isNull` | `true` when `.null` |
| `json["key"]` | Object subscript (read/write) |
| `json[0]` | Array subscript (read/write) |
| `json[keyPath: "a.b.c"]` | Dot-path subscript (read/write) |
| `json.name` | `@dynamicMemberLookup` shorthand |
| `value(forKey:)` | Throwing object key access |
| `value(at:)` | Throwing array index access |
| `for item in json` | Sequence iteration (arrays) |
| `merging(_:)` / `merge(_:)` | Merge two object nodes |
| `jsonCompatible` | Convert to `JSONSerialization`-compatible `Any` |
| `inferredSchema()` | Derive a `JSONSchema` from this value |
| `validate(against:)` | Throw on first schema violation |
| `isValid(against:)` | Bool — passes all constraints? |
| `validationResult(against:)` | All violations collected |

### `JSONSchema`

| API | Description |
|---|---|
| `.string(description:enumValues:minLength:maxLength:pattern:)` | String schema |
| `.number(description:minimum:maximum:exclusiveMinimum:exclusiveMaximum:)` | Float schema |
| `.integer(description:minimum:maximum:…)` | Integer schema |
| `.boolean()` / `.null()` | Boolean / null schemas |
| `.array(items:description:minItems:maxItems:uniqueItems:)` | Array schema |
| `.object(properties:required:additionalProperties:description:title:)` | Object schema |
| `.anyOf(_:)` / `.oneOf(_:)` / `.allOf(_:)` | Composition |
| `.nullable` | Shorthand for `anyOf([self, .null()])` |
| `.from(T.self)` | Schema from any `JSONConvertible` type |
| `.build(title:description:) { ... }` | `@resultBuilder` DSL |
| `.infer(from:)` | Derive schema from a JSON value |
| `validate(_:)` / `isValid(_:)` / `validationResult(for:)` | Validation |
| `Hashable`, `Equatable`, `Codable`, `CustomStringConvertible` | Full protocol suite |

---

## License

MIT
