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

    private func newEnv() -> QuestionOntologyEnvironment<WikidataOntologyMappings> {
        return .init()
    }

    func testQ1() throws {
        let compiler = try newCompiler()
        let result = try compiler.compile(
            question: .person(.named([t("died", "VBD", "die")]))
        )

        let Person = testQuestionOntology.classes["Person"]!
        let isA = testQuestionOntology.properties["isA"]!
        let died = testQuestionOntology.properties["died"]!

        let env = newEnv()

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

        let env = newEnv()

        let person = try env.newNode()
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

        let env = newEnv()

        let person = try env.newNode()
            .isA(Person)

        let obama = try env.newNode()
            .hasLabel(testQuestionOntology, "Obama")

        let expected = person
            .incoming(obama, hasSpouse)

        diffedAssertEqual([expected], result)
    }

     func testQ4() throws {
        let compiler = try newCompiler()
        let result = try compiler.compile(
            question: .person(
                .withFilter(
                    name: [t("died", "VBD", "die")],
                    filter: .withModifier(
                        modifier: [t("in", "IN", "in")],
                        value: .named([t("Berlin", "NNP", "berlin")])
                    )
                )
            )
        )

        let Person = testQuestionOntology.classes["Person"]!
        let died = testQuestionOntology.properties["died"]!

        let env = newEnv()

        let person = try env.newNode()
            .isA(Person)

        let berlin = try env.newNode()
            .hasLabel(testQuestionOntology, "Berlin")

        let expected = person
            .outgoing(died, berlin)

        diffedAssertEqual([expected], result)
    }

    func testQ5() throws {
        let compiler = try newCompiler()
        let result = try compiler.compile(
            question: .other(
                .withProperty(
                    .named([t("wives", "NNS", "wife")]),
                    property: .withFilter(
                        name: [
                            t("were", "VBD", "be"),
                            t("born", "VBD", "bear")
                        ],
                        filter: .withModifier(
                            modifier: [t("in", "IN", "in")],
                            value: .named([t("Berlin", "NNP", "berlin")])
                        )
                    )
                )
            )
        )

        let Wife = testQuestionOntology.classes["Wife"]!
        let born = testQuestionOntology.properties["born"]!

        let env = newEnv()

        let wife = try env.newNode()
            .isA(Wife)

        let berlin = try env.newNode()
            .hasLabel(testQuestionOntology, "Berlin")

        let expected = wife
            .outgoing(born, berlin)

        diffedAssertEqual([expected], result)
    }

    func testQ6() throws {
        let compiler = try newCompiler()
        let result = try compiler.compile(
            question: .other(
                .relationship(
                    .named([t("children", "NNS", "child")]),
                    .named([t("Obama", "NNP", "obama")]),
                    token: t("'s", "POS", "'s")
                )
            )
        )
        let env = newEnv()

        let Child = testQuestionOntology.classes["Child"]!
        let hasChild = testQuestionOntology.properties["hasChild"]!

        let obama = try env.newNode()
            .hasLabel(testQuestionOntology, "Obama")

        let expected = try env.newNode()
            .incoming(obama, hasChild)
            .isA(Child)

        diffedAssertEqual([expected], result)
    }

    func testQ7() throws {
        let compiler = try newCompiler()
        let result = try compiler.compile(
            question: .other(
                .relationship(
                    .named([t("wife", "NNS", "wife")]),
                    .named([t("Obama", "NNP", "obama")]),
                    token: t("'s", "POS", "'s")
                )
            )
        )

        let env = newEnv()

        let Wife = testQuestionOntology.classes["Wife"]!
        let hasSpouse = testQuestionOntology.properties["hasSpouse"]!

        let obama = try env.newNode()
            .hasLabel(testQuestionOntology, "Obama")

        let expected = try env.newNode()
            .outgoing(hasSpouse, obama)
            .isA(Wife)

        diffedAssertEqual([expected], result)
    }
}
