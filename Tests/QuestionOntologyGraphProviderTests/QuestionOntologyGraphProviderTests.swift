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
            .outgoing(isA, Person)
        let expected = person
            .outgoing(died, env.newNode())

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
        let born = testQuestionOntology.properties["born"]!

        let env = QuestionOntologyEnvironment<WikidataOntologyMappings>()
        let person = env.newNode()
            .isA(Person)

        let expected = person
            .outgoing(born, env.newNode())

        diffedAssertEqual([expected], result)
    }

    func testQ3() throws {
        let compiler = try newCompiler()
        let result = try compiler.compile(
            question: .person(
                .inverseWithFilter(
                    name: [
                        t("did", "VBD", "do"),
                        t("marry", "VB", "marry")
                    ],
                    filter: .plain(.named([
                        t("Obama", "NNP", "obama")
                    ]))
                )
            )
        )

        let Person = testQuestionOntology.classes["Person"]!
        let hasSpouse = testQuestionOntology.properties["hasSpouse"]!
        let env = QuestionOntologyEnvironment<WikidataOntologyMappings>()
        let person = env.newNode()
            .isA(Person)

        let obama = env.newNode()
            .hasLabel("Obama")
        let expected = person
            .incoming(obama, hasSpouse)

        diffedAssertEqual([expected], result)
    }

}

extension Node where Labels == HighLevelLabels<WikidataOntologyMappings> {


    func isA(_ `class`: Class<WikidataOntologyMappings>) -> Node {
        let isA = testQuestionOntology.properties["isA"]!
        return outgoing(isA, `class`)
    }

    func hasLabel(_ label: String) -> Node {
        let labelProperty = testQuestionOntology.labelProperty!
        return outgoing(labelProperty, .string(label))
    }
}
