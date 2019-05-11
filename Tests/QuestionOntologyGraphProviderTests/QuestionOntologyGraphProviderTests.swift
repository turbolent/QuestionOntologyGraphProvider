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
            .isA(testQuestionOntology, Person)

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
            .isA(testQuestionOntology, Person)

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
            .isA(testQuestionOntology, Person)

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
            .isA(testQuestionOntology, Wife)

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

        let Child = testQuestionOntology.classes["Child"]!
        let hasChild = testQuestionOntology.properties["hasChild"]!

        let env = newEnv()

        let obama = try env.newNode()
            .hasLabel(testQuestionOntology, "Obama")

        let expected = try env.newNode()
            .isA(testQuestionOntology, Child)
            .incoming(obama, hasChild)

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

        let Wife = testQuestionOntology.classes["Wife"]!
        let hasSpouse = testQuestionOntology.properties["hasSpouse"]!

        let env = newEnv()

        let obama = try env.newNode()
            .hasLabel(testQuestionOntology, "Obama")

        let expected = try env.newNode()
            .isA(testQuestionOntology, Wife)
            .outgoing(hasSpouse, obama)

        diffedAssertEqual([expected], result)
    }

    func testQ8() throws {
        let compiler = try newCompiler()
        let result = try compiler.compile(
            question: .person(
                .adjectiveWithFilter(
                    name: [
                        t("is", "VBZ", "be"),
                        t("old", "JJ", "old"),
                    ],
                    filter: .plain(.numberWithUnit(
                        [t("42", "CD", "42")],
                        unit: [t("years", "NNS", "year")]
                    ))
                )
            )
        )

        let Person = testQuestionOntology.classes["Person"]!
        let hasAge = testQuestionOntology.properties["hasAge"]!

        let env = newEnv()

        let expected = try env.newNode()
            .isA(testQuestionOntology, Person)
            .outgoing(hasAge, .number(42, unit: "year"))

        diffedAssertEqual([expected], result)
    }

    func testQ9() throws {
        let compiler = try newCompiler()
        let result = try compiler.compile(
            question: .person(
                .withFilter(
                    name: [t("is", "VBZ", "be")],
                    filter: .withComparativeModifier(
                        modifier: [
                            t("older", "JJR", "old"),
                            t("than", "IN", "than")
                        ],
                        value: .named([t("Obama", "NNP", "obama")])
                    )
                )
            )
        )

        let Person = testQuestionOntology.classes["Person"]!
        let hasAge = testQuestionOntology.properties["hasAge"]!

        let env = newEnv()

        let person = try env.newNode()
            .isA(testQuestionOntology, Person)

        let obama = try env
            .newNode()
            .hasLabel(testQuestionOntology, "Obama")

        let obamasAge = env
            .newNode()
            .incoming(obama, hasAge)

        let age = env
            .newNode()
            .filtered(.greaterThan(obamasAge))

        let expected = person
            .outgoing(hasAge, age)

        diffedAssertEqual([expected], result)
    }

    func testQ10() throws {
        let compiler = try newCompiler()
        let result = try compiler.compile(
            question: .person(
                .withFilter(
                    name: [t("is", "VBZ", "be")],
                    filter: .withComparativeModifier(
                        modifier: [
                            t("younger", "JJR", "young"),
                            t("than", "IN", "than")
                        ],
                        value: .named([t("Obama", "NNP", "obama")])
                    )
                )
            )
        )

        let Person = testQuestionOntology.classes["Person"]!
        let hasAge = testQuestionOntology.properties["hasAge"]!

        let env = newEnv()

        let person = try env.newNode()
            .isA(testQuestionOntology, Person)

        let obama = try env
            .newNode()
            .hasLabel(testQuestionOntology, "Obama")

        let obamasAge = env
            .newNode()
            .incoming(obama, hasAge)

        let age = env
            .newNode()
            .filtered(.lessThan(obamasAge))

        let expected = person
            .outgoing(hasAge, age)

        diffedAssertEqual([expected], result)
    }

    func testQ11() throws {
        let compiler = try newCompiler()
        let result = try compiler.compile(
            question: .other(
                .withProperty(
                    .named([t("men", "NNS", "man")]),
                    property: .withFilter(
                        name: [
                            t("were", "VBD", "be"),
                            t("born", "VBN", "bear")
                        ],
                        filter: .withModifier(
                            modifier: [t("before", "IN", "before")],
                            value: .number([t("1900", "CD", "1900")])
                        )
                    )
                )
            )
        )

        let Male = testQuestionOntology.classes["Male"]!
        let hasDateOfBirth = testQuestionOntology.properties["hasDateOfBirth"]!

        let env = newEnv()

        let male = try env.newNode()
            .isA(testQuestionOntology, Male)

        let nineteenHundred: Node<HighLevelLabels<WikidataOntologyMappings>> =
            Node(label: .number(1900, unit: nil))

        let birthDate = env
            .newNode()
            .filtered(.lessThan(nineteenHundred))

        let expected = male
            .outgoing(hasDateOfBirth, birthDate)

        diffedAssertEqual([expected], result)
    }
}
