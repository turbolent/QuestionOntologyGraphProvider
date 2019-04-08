
import QuestionCompiler
import QuestionParser
import QuestionOntology

public final class QuestionOntologyGraphProvider<Ontology, Mapping>: GraphProvider
    where Ontology: QuestionOntology<Mapping>
{
    public enum Error: Swift.Error {
        case notImplemented
    }

    public typealias Labels = QuestionOntologyLabels
    public typealias Env = QuestionOntologyEnvironment

    public let ontology: Ontology

    public init(ontology: Ontology) {
        self.ontology = ontology
    }

    public func makePersonEdge(
        env _: Env
    ) throws -> QuestionOntologyGraphProvider.Edge {
        throw Error.notImplemented
    }

    public func makeNamedPropertyEdge(
        name: [Token],
        node: QuestionOntologyGraphProvider.Node,
        subject _: Subject,
        env _: Env
    ) throws -> QuestionOntologyGraphProvider.Edge {
        throw Error.notImplemented
    }

    public func makeInversePropertyEdge(
        name: [Token],
        node: QuestionOntologyGraphProvider.Node,
        context _: EdgeContext,
        env _: Env
    ) throws -> QuestionOntologyGraphProvider.Edge {
        throw Error.notImplemented
    }

    public func makeAdjectivePropertyEdge(
        name: [Token],
        node: QuestionOntologyGraphProvider.Node,
        context: EdgeContext,
        env _: Env
    ) throws -> QuestionOntologyGraphProvider.Edge {
        throw Error.notImplemented
    }

    public func makeComparativePropertyEdge(
        name: [Token],
        node: QuestionOntologyGraphProvider.Node,
        context: EdgeContext,
        env: Env
    ) throws -> QuestionOntologyGraphProvider.Edge {
        throw Error.notImplemented
    }

    public func makeValuePropertyEdge(
        name: [Token],
        node: QuestionOntologyGraphProvider.Node,
        context: EdgeContext,
        env: Env
    ) throws -> QuestionOntologyGraphProvider.Edge {
        throw Error.notImplemented
    }

    public func makeRelationshipEdge(
        name: [Token],
        node: QuestionOntologyGraphProvider.Node,
        env _: Env
    ) throws -> QuestionOntologyGraphProvider.Edge {
        throw Error.notImplemented
    }

    public func makeValueNode(
        name: [Token],
        filter _: [Token],
        env: Env
    ) throws -> QuestionOntologyGraphProvider.Node {
        throw Error.notImplemented
    }

    public func makeNumberNode(
        number: [Token],
        unit: [Token],
        filter _: [Token],
        env _: Env
    ) throws -> QuestionOntologyGraphProvider.Node {
        throw Error.notImplemented
    }
}
