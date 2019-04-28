import Foundation
import QuestionCompiler
import QuestionParser
import QuestionOntology
import ParserDescription
import Regex
import ParserDescriptionOperators


public enum Error: Swift.Error {
    case notAvailable
    case invalidNumber(String)
}


extension Error: LocalizedError {

    public var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "not available"
        case let .invalidNumber(number):
            return "not a valid number: \(number)"
        }
    }
}


struct Patterns {
    private init() {}

    static let be = TokenPattern(
        condition:
        LabelCondition(label: "lemma", op: .isEqualTo, input: "be")
            && LabelCondition(label: Label.broadTag.rawValue, op: .isEqualTo, input: "V")
    )

    static let than = TokenPattern(
        condition:
        LabelCondition(label: "lemma", op: .isEqualTo, input: "than")
            && LabelCondition(label: Label.fineTag.rawValue, op: .isEqualTo, input: "IN")
    )
}


enum Comparison: Hashable {
    case greaterThan
    case lessThan
}

struct ComparativePropertyInstructionResult: Hashable {
    let propertyIdentifier: String
    let comparison: Comparison
}



public final class QuestionOntologyGraphProvider<Mappings>: GraphProvider
    where Mappings: OntologyMappings
{
    public typealias Labels = HighLevelLabels<Mappings>
    public typealias Env = QuestionOntologyEnvironment<Mappings>
    public typealias Ontology = QuestionOntology<Mappings>
    public typealias Token = QuestionParser.Token

    public let ontology: Ontology

    private let personEdge: QuestionOntologyGraphProvider.Edge?
    private let namedPropertyInstruction: TokenInstruction<String>
    private let inversePropertyInstruction: TokenInstruction<String>
    private let valuePropertyInstruction: TokenInstruction<String>
    private let adjectivePropertyInstruction: TokenInstruction<String>
    private let comparativePropertyInstruction: TokenInstruction<ComparativePropertyInstructionResult>
    private let namedClassInstruction: TokenInstruction<String>

    public init(ontology: Ontology) throws {
        self.ontology = ontology

        personEdge =
            QuestionOntologyGraphProvider.makePersonEdge(ontology: ontology)

        namedPropertyInstruction =
            try QuestionOntologyGraphProvider
                .compilePropertyPatternInstruction(ontology: ontology) { property, propertyPattern in
                    guard case let ._named(pattern) = propertyPattern else {
                        return nil
                    }
                    return (pattern, property.identifier)
                }

        inversePropertyInstruction =
            try QuestionOntologyGraphProvider
                .compilePropertyPatternInstruction(ontology: ontology) { property, propertyPattern in
                    guard case let ._inverse(pattern) = propertyPattern else {
                        return nil
                    }
                    return (pattern, property.identifier)
                }

        valuePropertyInstruction =
            try QuestionOntologyGraphProvider
                .compilePropertyPatternInstruction(ontology: ontology) { property, propertyPattern in
                    guard case let ._value(pattern) = propertyPattern else {
                        return nil
                    }
                    return (pattern, property.identifier)
                }

        adjectivePropertyInstruction =
            try QuestionOntologyGraphProvider
                .compilePropertyPatternInstruction(ontology: ontology) { property, propertyPattern in
                    guard case let ._adjective(pattern) = propertyPattern else {
                        return nil
                    }

                    // NOTE: prefix with be/VB
                    return (.sequence(Patterns.be ~ pattern), property.identifier)
                }

        comparativePropertyInstruction =
            try QuestionOntologyGraphProvider
                .compilePropertyPatternInstruction(ontology: ontology) { property, propertyPattern in
                    // NOTE: prefix with be/V and suffix with than/IN
                    func wrap(pattern: AnyPattern) -> AnyPattern {
                        return .sequence(Patterns.be ~ pattern ~ Patterns.than)
                    }

                    switch propertyPattern {
                    case let ._adjective(pattern):
                        return (
                            wrap(pattern: pattern),
                            ComparativePropertyInstructionResult(
                                propertyIdentifier: property.identifier,
                                comparison: .greaterThan
                            )
                        )
                    case let ._oppositeAdjective(pattern):
                        return (
                            wrap(pattern: pattern),
                            ComparativePropertyInstructionResult(
                                propertyIdentifier: property.identifier,
                                comparison: .lessThan
                            )
                        )
                    default:
                        return nil
                    }
            }

        namedClassInstruction =
            try QuestionOntologyGraphProvider
                .compileClassPatternInstruction(ontology: ontology) {
                    guard case let ._named(pattern) = $0 else {
                        return nil
                    }
                    return pattern
            }
    }

    private static func makePersonEdge(ontology: Ontology)
        -> QuestionOntologyGraphProvider.Edge?
    {
        guard
            let personClass = ontology.personClass,
            let instanceProperty = ontology.instanceProperty
        else {
            return nil
        }

        return .outgoing(
            instanceProperty,
            personClass
        )
    }

    public static func compilePropertyPatternInstruction<Result>(
        ontology: Ontology,
        mapping: (OntologyProperty<Mappings>, PropertyPattern) -> (AnyPattern, Result)?
    )
        throws -> TokenInstruction<Result>
        where Result: Hashable
    {
        return try compilePatternInstruction(patternsAndResults:
            ontology.properties.values.flatMap { property in
                property.patterns.compactMap { pattern in
                    mapping(property, pattern)
                }
            }
        )
    }

    public static func compileClassPatternInstruction(
        ontology: Ontology,
        filter: (ClassPattern) -> AnyPattern?
    )
        throws -> TokenInstruction<String>
    {
        return try compilePatternInstruction(patternsAndResults:
            ontology.classes.values
                .flatMap { `class` in
                    `class`.patterns
                        .compactMap(filter)
                        .map { ($0, `class`.identifier) }
            }
        )
    }

    private static func compilePatternInstruction<Result>(
        patternsAndResults: [(pattern: AnyPattern, result: Result)]
    )
        throws -> TokenInstruction<Result>
        where Result: Hashable
    {
        return compile(
            instructions: try patternsAndResults
                .map { try $0.compile(result: $1) }
        )
    }

    public func makePersonEdge(env _: Env) throws
        -> QuestionOntologyGraphProvider.Edge
    {
        guard let personEdge = personEdge else {
            throw Error.notAvailable
        }
        return personEdge
    }

    public func makeNamedPropertyEdge(
        name: [Token],
        subject _: Subject,
        env: Env
    )
        throws -> QuestionOntologyGraphProvider.Edge
    {
        guard
            let propertyIdentifier = namedPropertyInstruction.match(name),
            let property = ontology.properties[propertyIdentifier]
        else {
            throw Error.notAvailable
        }

        return .outgoing(property, env.newNode())
    }

    public func makeInversePropertyEdge(
        name: [Token],
        node: QuestionOntologyGraphProvider.Node,
        context _: EdgeContext,
        env: Env
    )
        throws -> QuestionOntologyGraphProvider.Edge
    {
        guard
            let propertyIdentifier = inversePropertyInstruction.match(name),
            let property = ontology.properties[propertyIdentifier]
        else {
            throw Error.notAvailable
        }

        return .incoming(node, property)
    }

    public func makeAdjectivePropertyEdge(
        name: [Token],
        node: QuestionOntologyGraphProvider.Node,
        context: EdgeContext,
        env _: Env
    ) throws -> QuestionOntologyGraphProvider.Edge {

        guard
            let propertyIdentifier = adjectivePropertyInstruction.match(name + context.filter),
            let property = ontology.properties[propertyIdentifier]
        else {
            throw Error.notAvailable
        }

        return .outgoing(property, node)
    }

    public func makeComparativePropertyEdge(
        name: [Token],
        node: QuestionOntologyGraphProvider.Node,
        context: EdgeContext,
        env: Env
    )
        throws -> QuestionOntologyGraphProvider.Edge
    {
        guard
            let result =
                comparativePropertyInstruction.match(name + context.filter),
            let property = ontology.properties[result.propertyIdentifier]
        else {
            throw Error.notAvailable
        }

        let otherValue = env.newNode()
            .incoming(node, property)

        let filter: GraphFilter<Labels>
        switch result.comparison {
        case .greaterThan:
            filter = .greaterThan(otherValue)
        case .lessThan:
            filter = .lessThan(otherValue)
        }

        let value = env.newNode()
            .filtered(filter)

        return .outgoing(property, value)
    }

    public func makeValuePropertyEdge(
        name: [Token],
        node: QuestionOntologyGraphProvider.Node,
        context: EdgeContext,
        env: Env
    )
        throws -> QuestionOntologyGraphProvider.Edge
    {
        guard
            let propertyIdentifier = valuePropertyInstruction.match(name + context.filter),
            let property = ontology.properties[propertyIdentifier]
        else {
            throw Error.notAvailable
        }

        return .outgoing(property, node)
    }

    public func makeRelationshipEdge(
        name: [Token],
        node: QuestionOntologyGraphProvider.Node,
        env: Env
    )
        throws -> QuestionOntologyGraphProvider.Edge
    {
        // the returned edge consists of two parts:
        // 1. an instance-of edge for a class with the given name
        // 2. a single edge or disjunction of edges to the node,
        //    labeled with an equivalent property of the class or superclasses

        // find class and create instance-of edge
        guard
            let classIdentifier = namedClassInstruction.match(name),
            let `class` = ontology.classes[classIdentifier]
        else {
            throw Error.notAvailable
        }

        let instanceEdge: Edge = try .isA(`class`)

        // find equivalents with a single, property segment.
        // recursivly search the superclasses if this class has none

        var currentClass = `class`
        var equivalentPropertySegments: [PropertySegment<Mappings>]
        var superClasses: [Class<Mappings>] = []

        repeat {
            equivalentPropertySegments = currentClass.equivalentPropertySegments
            superClasses.append(contentsOf: currentClass.superClasses)

            currentClass = superClasses.removeFirst()
        } while equivalentPropertySegments.isEmpty && !superClasses.isEmpty

        guard !equivalentPropertySegments.isEmpty else {
            throw Error.notAvailable
        }

        var edges = equivalentPropertySegments.map { $0.edge(node: node) }
        edges.append(instanceEdge)

        return .conjunction(edges)
    }

    public func makeValueNode(name: [Token], filter: [Token], env: Env)
        throws -> QuestionOntologyGraphProvider.Node
    {
        // find class and create instance-of node
        if
            let classIdentifier = namedClassInstruction.match(name),
            let `class` = ontology.classes[classIdentifier]
        {
            return try env.newNode().isA(`class`)
        }

        // fall back to labeled node

        let nameString = name
            .map { $0.word }
            .joined(separator: " ")

        return try labeled(label: nameString, env: env)
    }

    private func labeled(label: String, env: Env)
        throws -> QuestionOntologyGraphProvider.Node
    {
        guard let labelProperty = ontology.labelProperty else {
            throw Error.notAvailable
        }

        return env.newNode()
            .outgoing(labelProperty, .string(label))
    }

    public func makeNumberNode(number: [Token], unit: [Token], filter: [Token], env: Env)
        throws -> QuestionOntologyGraphProvider.Node
    {
        let numberString = number.map { $0.lemma }.joined(separator: " ")

        guard let number = Float(numberString) else {
            throw Error.invalidNumber(numberString)
        }

        let unitString = unit.isEmpty
            ? nil
            : unit.map { $0.lemma }.joined(separator: " ")

        return Node(label: .number(number, unit: unitString))
    }
}
