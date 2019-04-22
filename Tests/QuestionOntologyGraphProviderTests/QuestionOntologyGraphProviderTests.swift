import XCTest
import QuestionCompiler
import QuestionOntology
import QuestionOntologyGraphProvider
import TestQuestionOntology
import QuestionParser
import DiffedAssertEqual


func t(_ word: String, _ tag: String, _ lemma: String) -> Token {
    return Token(word: word, tag: tag, lemma: lemma)
}


final class QuestionOntologyGraphProviderTests: XCTestCase {

    typealias TestQuestionOntology = QuestionOntology<WikidataOntologyMappings>
    typealias TestGraphProvider = QuestionOntologyGraphProvider<WikidataOntologyMappings>

    private func newCompiler() throws -> QuestionCompiler<TestGraphProvider> {
        let environment = QuestionOntologyEnvironment<WikidataOntologyMappings>()
        let provider = try QuestionOntologyGraphProvider(ontology: testQuestionOntology)
        return QuestionCompiler(environment: environment, provider: provider)
    }

    func testQ1() throws {
        let compiler = try newCompiler()
        let result = try compiler.compile(
            question: .person(.named([t("died", "VBD", "die")]))
        )

        let Person = testQuestionOntology.classes["Person"]!
        let isA = testQuestionOntology.properties["isA"]!
        let died = testQuestionOntology.properties["died"]!

        let env = QuestionOntologyEnvironment<WikidataOntologyMappings>()
        let person = env.newNode()
            .and(.outgoing(
                HighLevelLabels.Edge(property: isA),
                Node(label: HighLevelLabels.Node.`class`(Person))
            ))
        let expected = person
            .outgoing(.init(property: died), env.newNode())

        diffedAssertEqual([expected], result)

    }

    func testQ2() throws {
        let compiler = try newCompiler()
        let result = try compiler.compile(
            question: .person(.named([
                t("was", "VBD", "be"),
                t("born", "VBD", "bear")
            ]))
        )

        let Person = testQuestionOntology.classes["Person"]!
        let isA = testQuestionOntology.properties["isA"]!
        let born = testQuestionOntology.properties["born"]!

        let env = QuestionOntologyEnvironment<WikidataOntologyMappings>()
        let person = env.newNode()
            .and(.outgoing(
                HighLevelLabels.Edge(property: isA),
                Node(label: HighLevelLabels.Node.`class`(Person))
            ))
        let expected = person
            .outgoing(.init(property: born), env.newNode())

        diffedAssertEqual([expected], result)

    }
}
