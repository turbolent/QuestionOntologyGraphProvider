import QuestionCompiler
import QuestionOntology


public extension Edge {

    static func outgoing<M>(_ property: Property<M>, _ `class`: Class<M>)
        -> Edge
        where M: OntologyMappings,
            Labels == HighLevelLabels<M>
    {
        return outgoing(
            property,
            HighLevelLabels.Node.`class`(`class`)
        )
    }

    static func outgoing<M>(_ property: Property<M>, _ nodeLabel: HighLevelLabels<M>.Node)
        -> Edge
        where M: OntologyMappings,
            Labels == HighLevelLabels<M>
    {
        return outgoing(
            property,
            Node(label: nodeLabel)
        )
    }

    static func outgoing<M>(_ property: Property<M>, _ node: Node)
        -> Edge
        where M: OntologyMappings,
        Labels == HighLevelLabels<M>
    {
        return outgoing(
            HighLevelLabels.Edge(property: property),
            node
        )
    }

    static func incoming<M>(_ nodeLabel: HighLevelLabels<M>.Node, _ property: Property<M>)
        -> Edge
        where M: OntologyMappings,
            Labels == HighLevelLabels<M>
    {
        return incoming(
            Node(label: nodeLabel),
            property
        )
    }

    static func incoming<M>(_ node: Node, _ property: Property<M>)
        -> Edge
        where M: OntologyMappings,
            Labels == HighLevelLabels<M>
    {
        return incoming(
            node,
            HighLevelLabels.Edge(property: property)
        )
    }
}


public extension Edge {

    static func isA<M>(_ `class`: Class<M>)
        throws -> Edge
        where M: OntologyMappings,
            Labels == HighLevelLabels<M>
    {
        guard let instanceProperty = `class`.ontology.instanceProperty else {
            throw Error.notAvailable
        }
        return .outgoing(instanceProperty, `class`)
    }

    static func hasLabel<M>(_ ontology: QuestionOntology<M>, _ label: String)
        throws -> Edge
        where M: OntologyMappings,
            Labels == HighLevelLabels<M>
    {
        guard let labelProperty = ontology.labelProperty else {
            throw Error.notAvailable
        }
        return .outgoing(labelProperty, .string(label))
    }
}
