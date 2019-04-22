
import QuestionCompiler
import QuestionOntology


public struct HighLevelLabels<M>: GraphLabels
    where M: OntologyMappings
{
    private init() {}

    public enum Node: NodeLabel, Equatable {
        case variable(Int)
        case `class`(Class<M>)
        case individual(Individual<M>)
    }

    public struct Edge: EdgeLabel, Equatable {
        public let property: Property<M>

        public init(property: Property<M>) {
            self.property = property
        }
    }
}

