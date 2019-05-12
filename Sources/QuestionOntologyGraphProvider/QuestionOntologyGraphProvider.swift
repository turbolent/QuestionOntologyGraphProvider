import Foundation
import QuestionCompiler
import QuestionParser
import QuestionOntology


public enum ProviderError: Error {
    case notAvailable
    case invalidNumber(String)
}


extension ProviderError: LocalizedError {

    public var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "not available"
        case let .invalidNumber(number):
            return "not a valid number: \(number)"
        }
    }
}


public enum OntologyError: Error {
    case invalidPropertyIdentifier(String)
    case invalidClassIdentifier(String)
}


extension OntologyError: LocalizedError {

    public var errorDescription: String? {
        switch self {
        case let .invalidPropertyIdentifier(identifier):
            return "invalid property: \(identifier)"
        case let .invalidClassIdentifier(identifier):
            return "invalid class: \(identifier)"
        }
    }
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
    private let ontologyElements: QuestionOntologyElements<Mappings>

    public init(ontology: Ontology) throws {
        self.ontology = ontology
        personEdge =
            QuestionOntologyGraphProvider.makePersonEdge(ontology: ontology)

        ontologyElements = try QuestionOntologyElements(ontology: ontology)
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

    public func makePersonEdge(env _: Env) throws
        -> QuestionOntologyGraphProvider.Edge
    {
        guard let personEdge = personEdge else {
            throw ProviderError.notAvailable
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
        let properties = ontologyElements.findNamedProperties(name: name)

        guard !properties.isEmpty else {
            throw ProviderError.notAvailable
        }

        return Edge(disjunction: properties.map {
            .outgoing($0, env.newNode())
        })
    }

    public func makeInversePropertyEdge(
        name: [Token],
        node: QuestionOntologyGraphProvider.Node,
        context _: EdgeContext,
        env: Env
    )
        throws -> QuestionOntologyGraphProvider.Edge
    {
        let properties = ontologyElements.findInverseProperties(name: name)

        guard !properties.isEmpty else {
            throw ProviderError.notAvailable
        }

        return Edge(disjunction: properties.map {
            .incoming(node, $0)
        })
    }

    public func makeAdjectivePropertyEdge(
        name: [Token],
        node: QuestionOntologyGraphProvider.Node,
        context: EdgeContext,
        env _: Env
    ) throws -> QuestionOntologyGraphProvider.Edge {

        let properties = ontologyElements
            .findAdjectiveProperties(name: name + context.filter)

        guard !properties.isEmpty else {
            throw ProviderError.notAvailable
        }

        return Edge(disjunction: properties.map {
            .outgoing($0, node)
        })
    }

    public func makeComparativePropertyEdge(
        name: [Token],
        node: QuestionOntologyGraphProvider.Node,
        context: EdgeContext,
        env: Env
    )
        throws -> QuestionOntologyGraphProvider.Edge
    {
        let results = ontologyElements
            .findComparativeProperties(name: name + context.filter)

        guard !results.isEmpty else {
            throw ProviderError.notAvailable
        }

        return Edge(disjunction: results.map { result in

            let otherValue = env.newNode()
                .incoming(node, result.property)

            let filter: GraphFilter<Labels>
            switch result.comparison {
            case .greaterThan:
                filter = .greaterThan(otherValue)
            case .lessThan:
                filter = .lessThan(otherValue)
            }

            let value = env.newNode()
                .filtered(filter)

            return .outgoing(result.property, value)
        })
    }

    public func makeValuePropertyEdge(
        name: [Token],
        node: QuestionOntologyGraphProvider.Node,
        context: EdgeContext,
        env: Env
    )
        throws -> QuestionOntologyGraphProvider.Edge
    {
        let results = ontologyElements
            .findValueProperties(name: name + context.filter)

        if !results.isEmpty {
            return Edge(disjunction: results.map { result in
                var node = node

                switch result.comparison {
                case nil:
                    break
                case .lessThan?:
                    node = env.newNode()
                        .filtered(.lessThan(node))
                case .greaterThan?:
                    node = env.newNode()
                        .filtered(.greaterThan(node))
                }

                return .outgoing(result.property, node)
            })
        }

        if case let .named(subject) = context.subject {

            let directedProperties = ontologyElements
                .findRelations(name: subject + context.filter)

            if !directedProperties.isEmpty {
                return Edge(disjunction: directedProperties.map { directedProperty in
                    directedProperty.edge(node: node)
                })
            }
        }

        throw ProviderError.notAvailable
    }

    public func makeRelationshipEdge(
        name: [Token],
        node: QuestionOntologyGraphProvider.Node,
        env: Env
    )
        throws -> QuestionOntologyGraphProvider.Edge
    {
        // the returned edge consists of two parts:
        // 1. an instance-of edge for the classes with the given name
        // 2. a single edge or disjunction of edges to the node

        // find class and create instance-of edge
        let classes = ontologyElements.findNamedClasses(name: name)

        guard !classes.isEmpty else {
            throw ProviderError.notAvailable
        }

        let instanceEdge = Edge(disjunction: try classes.map {
            try .isA(ontology, $0)
        })

        let directedProperties = ontologyElements.findRelations(name: name)

        guard !directedProperties.isEmpty else {
            throw ProviderError.notAvailable
        }

        let relationshipEdge =
            Edge(disjunction: directedProperties.map { directedProperty in
                directedProperty.edge(node: node)
            })

        return .conjunction([instanceEdge, relationshipEdge])
    }

    public func makeValueNode(name: [Token], filter _: [Token], env: Env)
        throws -> QuestionOntologyGraphProvider.Node
    {
        // find class and create instance-of node

        let classes = ontologyElements.findNamedClasses(name: name)

        if !classes.isEmpty {
            return env.newNode()
                .and(Edge(disjunction: try classes.map {
                    try .isA(ontology, $0)
                }))
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
            throw ProviderError.notAvailable
        }

        return env.newNode()
            .outgoing(labelProperty, .string(label))
    }

    public func makeNumberNode(number: [Token], unit: [Token], filter: [Token], env: Env)
        throws -> QuestionOntologyGraphProvider.Node
    {
        let numberString = number.map { $0.lemma }.joined(separator: " ")

        guard let number = Float(numberString) else {
            throw ProviderError.invalidNumber(numberString)
        }

        let unitString = unit.isEmpty
            ? nil
            : unit.map { $0.lemma }.joined(separator: " ")

        return Node(label: .number(number, unit: unitString))
    }

    public func isDisjunction(property: [Token], filter: [Token]) -> Bool {
        return property.isEmpty
            && filter.allSatisfy { $0.tag == "IN" }
    }
}
