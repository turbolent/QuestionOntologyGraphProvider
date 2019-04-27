import QuestionCompiler
import QuestionOntology


enum PropertySegment<M>
    where M: OntologyMappings
{
    case incoming(Property<M>)
    case outgoing(Property<M>)

    func edge(node: Node<HighLevelLabels<M>>) -> Edge<HighLevelLabels<M>> {
        switch self {
        case let .outgoing(property):
            return .outgoing(property, node)
        case let .incoming(property):
            return .incoming(node, property)
        }
    }
}


extension Class {

    var equivalentPropertySegments: [PropertySegment<M>] {
        return equivalents.flatMap { (equivalent: Equivalent<M>) -> [PropertySegment<M>] in
            guard case let .segments(segments) = equivalent else {
                return []
            }

            return segments.compactMap { (segment: Equivalent<M>.Segment) -> PropertySegment<M>? in
                switch segment.identifier {
                case let .outgoing(propertyIdentifier):
                    return ontology.properties[propertyIdentifier]
                        .map { .outgoing($0) }
                case let .incoming(propertyIdentifier):
                    return ontology.properties[propertyIdentifier]
                        .map { .incoming($0) }
                case .individual(_):
                    return nil
                }
            }
        }
    }
}
