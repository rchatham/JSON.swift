// JSONWithMacros.swift
//
// Umbrella module that re-exports the core JSON library together with the
// JSONMacroPlugin compiler plugin, enabling the @JSONSchema macro.
//
// Import this module (instead of JSON) when you want to use @JSONSchema:
//
//   import JSONWithMacros
//
//   @JSONSchema
//   struct WeatherCard: Codable {
//       let location: String
//       let temperature: Double
//   }
//
// If you only need JSON types and schema validation (no macro), import JSON:
//
//   import JSON

@_exported import JSON
