import Foundation
import QuestionCompiler
import QuestionParser
import QuestionOntology
import ParserDescription
import Regex


public final class QuestionOntologyGraphProvider<Mappings>: GraphProvider
    where Mappings: OntologyMappings
{
    public enum Error: Swift.Error {
        case notImplemented
        case notAvailable
    }

    public typealias Labels = HighLevelLabels<Mappings>
    public typealias Env = QuestionOntologyEnvironment<Mappings>
    public typealias Ontology = QuestionOntology<Mappings>
    public typealias Token = QuestionParser.Token

    public let ontology: Ontology

    private let personEdge: QuestionOntologyGraphProvider.Edge?
    private let namedPropertyInstruction: TokenInstruction<String>
    private let inversePropertyInstruction: TokenInstruction<String>

    public init(ontology: Ontology) throws {
        self.ontology = ontology

        personEdge =
            QuestionOntologyGraphProvider.makePersonEdge(ontology: ontology)

        namedPropertyInstruction =
            try QuestionOntologyGraphProvider.compilePropertyPatternInstruction(ontology: ontology) {
                guard case let ._named(pattern) = $0 else {
                    return nil
                }
                return pattern
            }

        inversePropertyInstruction =
            try QuestionOntologyGraphProvider.compilePropertyPatternInstruction(ontology: ontology) {
                guard case let ._inverse(pattern) = $0 else {
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

    private static func compilePropertyPatternInstruction(
        ontology: Ontology,
        filter: (PropertyPattern) -> AnyPattern?
    )
        throws -> TokenInstruction<String>
    {
        let instructions = try ontology.properties.values
            .flatMap { property in
                try property.patterns.compactMap { propertyPattern -> TokenInstruction<String>? in
                    guard let pattern = filter(propertyPattern) else {
                        return nil
                    }
                    return try pattern.compile(result: property.identifier)
                }
            }
        return compile(instructions: instructions)
    }

    public func makePersonEdge(
        env _: Env
    ) throws -> QuestionOntologyGraphProvider.Edge {
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
        throw Error.notImplemented
    }

    public func makeComparativePropertyEdge(
        name: [Token],
        node: QuestionOntologyGraphProvider.Node,
        context: EdgeContext,
        env: Env
    ) throws -> QuestionOntologyGraphProvider.Edge {
        throw Error.notImplemented
    }

    public func makeValuePropertyEdge(
        name: [Token],
        node: QuestionOntologyGraphProvider.Node,
        context: EdgeContext,
        env: Env
    ) throws -> QuestionOntologyGraphProvider.Edge {
        throw Error.notImplemented
    }

    public func makeRelationshipEdge(
        name: [Token],
        node: QuestionOntologyGraphProvider.Node,
        env _: Env
    ) throws -> QuestionOntologyGraphProvider.Edge {
        throw Error.notImplemented
    }

    public func makeValueNode(
        name: [Token],
        filter _: [Token],
        env: Env
    ) throws -> QuestionOntologyGraphProvider.Node {

        // TODO: find class

        guard let labelProperty = ontology.labelProperty else {
            throw Error.notAvailable
        }

        let nameString = name
            .map { $0.word }
            .joined(separator: " ")
        return env.newNode()
            .outgoing(labelProperty, .string(nameString))
    }

    public func makeNumberNode(
        number: [Token],
        unit: [Token],
        filter _: [Token],
        env _: Env
    ) throws -> QuestionOntologyGraphProvider.Node {
        throw Error.notImplemented
    }
}


extension QuestionOntologyGraphProvider.Error: LocalizedError {

    public var errorDescription: String? {
        switch self {
        case .notImplemented:
            return "not implemented"
        case .notAvailable:
            return "not available"
        }
    }
}
