import Foundation
import QuestionCompiler
import QuestionParser
import QuestionOntology
import OrderedSet


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

            let otherValue = context.valueIsNumber
                ? node
                : env.newNode().incoming(node, result.property)

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

            let directedProperties = findRelations(name: subject + context.filter)

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

        guard let classEdge = try getClassEdge(name: name, env: env) else {
            throw ProviderError.notAvailable
        }

        let directedProperties = findRelations(name: name)

        guard !directedProperties.isEmpty else {
            throw ProviderError.notAvailable
        }

        let relationshipEdge =
            Edge(disjunction: directedProperties.map { directedProperty in
                directedProperty.edge(node: node)
            })

        return .conjunction([classEdge, relationshipEdge])
    }

    public func makeValueNode(name: [Token], filter _: [Token], env: Env)
        throws -> QuestionOntologyGraphProvider.Node
    {
        // find class and create instance-of node

        if let classEdge = try getClassEdge(name: name, env: env) {
            return env.newNode().and(classEdge)
        }

        // fall back to labeled node

        let nameString = name.joinedWords

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
        let numberString = number.joinedLemmas

        guard let number = Float(numberString) else {
            throw ProviderError.invalidNumber(numberString)
        }

        let unitString = unit.isEmpty ? nil : unit.joinedLemmas

        return Node(label: .number(number, unit: unitString))
    }

    public func isDisjunction(property: [Token], filter: [Token]) -> Bool {
        return property.isEmpty
            && filter.allSatisfy { $0.tag == "IN" }
    }

    private func dropInitialDeterminer(name: [Token]) -> ArraySlice<Token> {
        guard let first = name.first, first.tag == "DT" else {
            return ArraySlice(name)
        }

        return name.dropFirst()
    }

    private struct AdjectiveEdge: Hashable {
        let edge: Edge<HighLevelLabels<Mappings>>
        let remainder: ArraySlice<Token>
    }

    private func getAdjectiveEdges(name: ArraySlice<Token>, env: Env)
        -> [AdjectiveEdge]
    {
        return ontologyElements.findAdjectivePrefix(name: name).map { match in
            var node = env.newNode()
            if let order = match.adjectivePrefix.order {
                let graphOrder: GraphOrder
                switch order {
                case .ascending:
                    graphOrder = .ascending
                case .descending:
                    graphOrder = .descending
                }
                node = node.ordered(graphOrder)
            }

            return AdjectiveEdge(
                edge: .outgoing(match.adjectivePrefix.property, node),
                remainder: name.dropFirst(match.length)
            )
        }
    }

    private func getClassEdge(name: [Token], env: Env)
        throws -> Edge<HighLevelLabels<Mappings>>?
    {
        let name = dropInitialDeterminer(name: name)

        let adjectiveEdges = getAdjectiveEdges(name: name, env: env)

        let suffixes = adjectiveEdges.isEmpty
            ? [ArraySlice(name)]
            : adjectiveEdges.map { $0.remainder }

        let classes = OrderedSet(suffixes.flatMap {
            ontologyElements.findNamedClasses(name: $0)
        })

        guard !classes.isEmpty else {
            return nil
        }

        let instanceEdge = Edge(disjunction: try classes.map {
            try .isA(ontology, $0)
        })

        if adjectiveEdges.isEmpty {
            return instanceEdge
        } else {
            return .conjunction([
                instanceEdge,
                Edge(disjunction: adjectiveEdges.map { $0.edge })
            ])
        }
    }

    private func findRelations(name: [Token]) -> OrderedSet<DirectedProperty<Mappings>> {
        let name = dropInitialDeterminer(name: name)
        return ontologyElements.findRelations(name: name)
    }
}
