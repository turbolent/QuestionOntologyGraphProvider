import QuestionCompiler
import QuestionOntology


enum PropertySegment<Mappings>
    where Mappings: OntologyMappings
{
    case incoming(Property<Mappings>)
    case outgoing(Property<Mappings>)

    func edge(node: Node<HighLevelLabels<Mappings>>) -> Edge<HighLevelLabels<Mappings>> {
        switch self {
        case let .outgoing(property):
            return .outgoing(property, node)
        case let .incoming(property):
            return .incoming(node, property)
        }
    }
}
