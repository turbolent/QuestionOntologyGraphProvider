import XCTest
import QuestionCompiler
import QuestionOntology
import QuestionOntologyGraphProvider
import TestQuestionOntology
import QuestionParser


func t(_ word: String, _ tag: String, _ lemma: String) -> Token {
    return Token(word: word, tag: tag, lemma: lemma)
}


final class QuestionOntologyGraphProviderTests: XCTestCase {

    typealias TestQuestionOntology = QuestionOntology<WikidataOntologyMappings>
    typealias TestGraphProvider = QuestionOntologyGraphProvider<TestQuestionOntology, WikidataOntologyMappings>

    private func newCompiler() -> QuestionCompiler<TestGraphProvider> {
        let environment = QuestionOntologyEnvironment()
        let provider = QuestionOntologyGraphProvider(ontology: testQuestionOntology)
        return QuestionCompiler(environment: environment, provider: provider)
    }

    func testExample() throws {
        let compiler = newCompiler()
        
    }
}
