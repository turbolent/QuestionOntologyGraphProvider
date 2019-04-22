import QuestionCompiler
import QuestionOntology


public final class QuestionOntologyEnvironment<Mappings>: Environment
    where Mappings: OntologyMappings
{
    public typealias Labels = HighLevelLabels<Mappings>

    private var count = 0

    public init() {}

    public func newNode() -> Node<Labels> {
        defer { count += 1 }
        return Node(label: .variable(count))
    }
}
