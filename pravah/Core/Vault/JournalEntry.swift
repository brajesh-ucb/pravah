import Foundation
import SwiftUI

enum SolarPhase: String, Codable, Sendable, CaseIterable {
    case day
    case goldenHour
    case night
}

struct JournalEntry: Identifiable, Codable, Sendable, Hashable {
    var id: UUID = UUID()
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var title: String
    var body: String
    var latitude: Double?
    var longitude: Double?
    var altitude: Double?
    var locationName: String?
    var solarPhase: SolarPhase
    var weatherSummary: String?
    var tags: [String] = []
    var assetRelativePaths: [String] = []
}

enum YAMLSerializerError: Error, Equatable, Sendable {
    case missingFrontmatter
    case unterminatedFrontmatter
    case missingField(String)
    case invalidValue(field: String, value: String)
}

nonisolated struct YAMLSerializer: Sendable {
    private static let delimiter = "---"
    private static let dateStyle = Date.ISO8601FormatStyle(includingFractionalSeconds: true)
    private static let plainDateStyle = Date.ISO8601FormatStyle()

    static func exportToMarkdown(_ entry: JournalEntry) -> String {
        let frontmatter = [
            delimiter,
            "id: \(entry.id.uuidString)",
            "created_at: \(entry.createdAt.formatted(dateStyle))",
            "updated_at: \(entry.updatedAt.formatted(dateStyle))",
            "title: \(quote(entry.title))",
            "lat: \(number(entry.latitude))",
            "lon: \(number(entry.longitude))",
            "alt: \(number(entry.altitude))",
            "location_name: \(optionalQuote(entry.locationName))",
            "solar_phase: \(entry.solarPhase.rawValue)",
            "weather: \(optionalQuote(entry.weatherSummary))",
            "tags: \(list(entry.tags))",
            "assets: \(list(entry.assetRelativePaths))",
            delimiter
        ]
        return frontmatter.joined(separator: "\n") + "\n" + entry.body
    }

    static func parseFromMarkdown(_ markdownContent: String) throws -> JournalEntry {
        let (fields, body) = try splitFrontmatter(markdownContent)
        let createdAt = try date(fields, "created_at")

        return JournalEntry(
            id: try uuid(fields),
            createdAt: createdAt,
            updatedAt: try optionalDate(fields, "updated_at") ?? createdAt,
            title: try requiredString(fields, "title"),
            body: body,
            latitude: try optionalNumber(fields, "lat"),
            longitude: try optionalNumber(fields, "lon"),
            altitude: try optionalNumber(fields, "alt"),
            locationName: try optionalString(fields, "location_name"),
            solarPhase: try solarPhase(fields),
            weatherSummary: try optionalString(fields, "weather"),
            tags: try stringList(fields, "tags"),
            assetRelativePaths: try stringList(fields, "assets")
        )
    }
}

// MARK: - Writing

nonisolated private extension YAMLSerializer {
    static func quote(_ value: String) -> String {
        var escaped = ""
        for character in value {
            switch character {
            case "\\": escaped += "\\\\"
            case "\"": escaped += "\\\""
            case "\n": escaped += "\\n"
            case "\r\n": escaped += "\\r\\n"
            case "\r": escaped += "\\r"
            case "\t": escaped += "\\t"
            default: escaped.append(character)
            }
        }
        return "\"\(escaped)\""
    }

    static func optionalQuote(_ value: String?) -> String {
        value.map(quote) ?? "null"
    }

    static func number(_ value: Double?) -> String {
        value.map { "\($0)" } ?? "null"
    }

    static func list(_ values: [String]) -> String {
        "[" + values.map(quote).joined(separator: ", ") + "]"
    }
}

// MARK: - Reading

nonisolated private extension YAMLSerializer {
    static func splitFrontmatter(_ content: String) throws -> (fields: [String: String], body: String) {
        guard let first = nextLine(in: content, from: content.startIndex),
              first.line == delimiter else {
            throw YAMLSerializerError.missingFrontmatter
        }

        var fields: [String: String] = [:]
        var cursor = first.next
        while let (line, next) = nextLine(in: content, from: cursor) {
            if line == delimiter {
                return (fields, String(content[next...]))
            }
            if let separator = line.firstIndex(of: ":") {
                let key = line[..<separator].trimmingCharacters(in: .whitespaces)
                fields[key] = line[line.index(after: separator)...].trimmingCharacters(in: .whitespaces)
            }
            cursor = next
        }
        throw YAMLSerializerError.unterminatedFrontmatter
    }

    static func nextLine(in content: String, from start: String.Index) -> (line: Substring, next: String.Index)? {
        guard start < content.endIndex else { return nil }
        guard let newline = content[start...].firstIndex(where: \.isNewline) else {
            return (content[start...], content.endIndex)
        }
        return (content[start..<newline], content.index(after: newline))
    }

    static func rawValue(_ fields: [String: String], _ key: String) throws -> String {
        guard let value = fields[key] else { throw YAMLSerializerError.missingField(key) }
        return value
    }

    static func uuid(_ fields: [String: String]) throws -> UUID {
        let raw = try rawValue(fields, "id")
        guard let id = UUID(uuidString: raw) else {
            throw YAMLSerializerError.invalidValue(field: "id", value: raw)
        }
        return id
    }

    static func solarPhase(_ fields: [String: String]) throws -> SolarPhase {
        let raw = try rawValue(fields, "solar_phase")
        guard let phase = SolarPhase(rawValue: raw) else {
            throw YAMLSerializerError.invalidValue(field: "solar_phase", value: raw)
        }
        return phase
    }

    static func date(_ fields: [String: String], _ key: String) throws -> Date {
        let raw = try rawValue(fields, key)
        if let parsed = try? dateStyle.parse(raw) { return parsed }
        if let parsed = try? plainDateStyle.parse(raw) { return parsed }
        throw YAMLSerializerError.invalidValue(field: key, value: raw)
    }

    static func optionalDate(_ fields: [String: String], _ key: String) throws -> Date? {
        fields[key] == nil ? nil : try date(fields, key)
    }

    static func optionalNumber(_ fields: [String: String], _ key: String) throws -> Double? {
        guard let raw = fields[key], raw != "null" else { return nil }
        guard let value = Double(raw) else {
            throw YAMLSerializerError.invalidValue(field: key, value: raw)
        }
        return value
    }

    static func requiredString(_ fields: [String: String], _ key: String) throws -> String {
        try unquote(try rawValue(fields, key), field: key)
    }

    static func optionalString(_ fields: [String: String], _ key: String) throws -> String? {
        guard let raw = fields[key], raw != "null" else { return nil }
        return try unquote(raw, field: key)
    }

    static func stringList(_ fields: [String: String], _ key: String) throws -> [String] {
        guard let raw = fields[key], raw != "null" else { return [] }
        guard raw.hasPrefix("["), raw.hasSuffix("]") else {
            throw YAMLSerializerError.invalidValue(field: key, value: raw)
        }
        return try listItems(String(raw.dropFirst().dropLast()), field: key)
    }

    static func listItems(_ inner: String, field: String) throws -> [String] {
        var items: [String] = []
        var remaining = inner[...]
        while let start = remaining.firstIndex(where: { $0 != " " && $0 != "," }) {
            remaining = remaining[start...]
            guard remaining.first == "\"" else {
                throw YAMLSerializerError.invalidValue(field: field, value: inner)
            }
            let end = try closingQuote(in: remaining, field: field)
            items.append(try unquote(String(remaining[...end]), field: field))
            remaining = remaining[remaining.index(after: end)...]
        }
        return items
    }

    static func closingQuote(in text: Substring, field: String) throws -> String.Index {
        var index = text.index(after: text.startIndex)
        while index < text.endIndex {
            if text[index] == "\\" {
                index = text.index(after: index)
                guard index < text.endIndex else { break }
            } else if text[index] == "\"" {
                return index
            }
            index = text.index(after: index)
        }
        throw YAMLSerializerError.invalidValue(field: field, value: String(text))
    }

    static func unquote(_ raw: String, field: String) throws -> String {
        guard raw.count >= 2, raw.hasPrefix("\""), raw.hasSuffix("\"") else { return raw }
        var result = ""
        var isEscaped = false
        for character in raw.dropFirst().dropLast() {
            if isEscaped {
                result += unescaped(character)
                isEscaped = false
            } else if character == "\\" {
                isEscaped = true
            } else {
                result.append(character)
            }
        }
        if isEscaped { throw YAMLSerializerError.invalidValue(field: field, value: raw) }
        return result
    }

    static func unescaped(_ character: Character) -> String {
        switch character {
        case "n": "\n"
        case "r": "\r"
        case "t": "\t"
        default: String(character)
        }
    }
}

#Preview("YAML Serialization Test") {
    let testEntry = JournalEntry(
        title: "Golden Hour Trail Sketch",
        body: "Recorded ambient observations near the stream.",
        latitude: 37.8270,
        longitude: -122.4998,
        locationName: "Marin Headlands",
        solarPhase: .goldenHour,
        tags: ["trail", "sketch"]
    )
    
    let markdownString = YAMLSerializer.exportToMarkdown(testEntry)
    
    return TextEditor(text: .constant(markdownString))
        .font(.system(.footnote, design: .monospaced))
        .padding()
}


