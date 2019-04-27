import QuestionCompiler
import QuestionOntology


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


public extension Node {

    func isA<M>(_ `class`: Class<M>)
        throws -> Node
        where M: OntologyMappings,
            Labels == HighLevelLabels<M>
    {
        return try and(.isA(`class`))
    }

    func hasLabel<M>(_ ontology: QuestionOntology<M>, _ label: String)
        throws -> Node
        where M: OntologyMappings,
        Labels == HighLevelLabels<M>
    {
        return try and(.hasLabel(ontology, label))
    }
}
