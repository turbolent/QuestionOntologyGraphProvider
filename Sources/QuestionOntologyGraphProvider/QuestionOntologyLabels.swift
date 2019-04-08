
import QuestionCompiler


public struct QuestionOntologyLabels: GraphLabels {
    public typealias Node = QuestionOntologyNodeLabel
    public typealias Edge = QuestionOntologyEdgeLabel

    private init() {}
}


public enum QuestionOntologyNodeLabel: NodeLabel {
    case variable(Int)
    case item(String)
    case string(String)
    case number(Double, unit: String?)
}

extension QuestionOntologyNodeLabel: Encodable {

    private enum CodingKeys: CodingKey {
        case type
        case subtype
        case name
        case id
        case value
        case url
    }

    private enum PrimaryType: String, Encodable {
        case item
        case variable
        case value
    }

    private enum Subtype: String, Encodable {
        case string
        case number
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case let .item(name):
            try container.encode(PrimaryType.item, forKey: .type)
            try container.encode(name, forKey: .name)
            // TODO: url

        case let .variable(id):
            try container.encode(PrimaryType.variable, forKey: .type)
            try container.encode(id, forKey: .id)

        case let .string(value):
            try container.encode(PrimaryType.value, forKey: .type)
            try container.encode(Subtype.string, forKey: .subtype)
            try container.encode(value, forKey: .value)

        case let .number(value, _):
            try container.encode(PrimaryType.value, forKey: .type)
            try container.encode(Subtype.number, forKey: .subtype)
            try container.encode(value, forKey: .value)
        }
    }
}

public struct QuestionOntologyEdgeLabel: EdgeLabel {
    public let name: String
}

extension QuestionOntologyEdgeLabel: Encodable {

    private enum CodingKeys: CodingKey {
        case type
        case name
        case url
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode("property", forKey: .type)
        try container.encode(name, forKey: .name)
        // TODO: url
    }
}
