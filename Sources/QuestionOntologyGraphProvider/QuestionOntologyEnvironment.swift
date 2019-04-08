
import QuestionCompiler
import QuestionParser

public class QuestionOntologyEnvironment: Environment {
    private var count = 0

    public init() {}

    public func newNode() -> Node<QuestionOntologyLabels> {
        defer { count += 1 }
        return Node(label: .variable(count))
    }
}
