
import QuestionCompiler
import QuestionOntology


public struct HighLevelLabels<M>: GraphLabels
    where M: OntologyMappings
{
    private init() {}

    public enum Node: NodeLabel, Hashable {
        case variable(Int)
        case `class`(Class<M>)
        case individual(Individual<M>)
        case string(String)
        case number(Float, unit: String?)
    }

    public struct Edge: EdgeLabel, Hashable {
        public let property: Property<M>

        public init(property: Property<M>) {
            self.property = property
        }
    }
}

