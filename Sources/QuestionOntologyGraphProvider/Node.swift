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

public extension Node {

    func outgoing<M>(_ property: Property<M>, _ `class`: Class<M>)
        -> Node
        where M: OntologyMappings,
        Labels == HighLevelLabels<M>
    {
        return and(.outgoing(property, `class`))
    }

    func outgoing<M>(_ property: Property<M>, _ nodeLabel: HighLevelLabels<M>.Node)
        -> Node
        where M: OntologyMappings,
            Labels == HighLevelLabels<M>
    {
        return and(.outgoing(property, nodeLabel))
    }

    func outgoing<M>(_ property: Property<M>, _ node: Node)
        -> Node
        where M: OntologyMappings,
            Labels == HighLevelLabels<M>
    {
        return and(.outgoing(property, node))
    }

    func incoming<M>(_ nodeLabel: HighLevelLabels<M>.Node, _ property: Property<M>)
        -> Node
        where M: OntologyMappings,
            Labels == HighLevelLabels<M>
    {
        return and(.incoming(nodeLabel, property))
    }

    func incoming<M>(_ node: Node, _ property: Property<M>)
        -> Node
        where M: OntologyMappings,
            Labels == HighLevelLabels<M>
    {
        return and(.incoming(node, property))
    }
}
