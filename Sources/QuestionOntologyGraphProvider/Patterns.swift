import QuestionOntology
import ParserDescription


struct Patterns {
    private init() {}

    static let be = pattern(lemma: "be", tag: .anyVerb)
    static let the = TokenPattern(condition:
        LabelCondition(
            label: Label.fineTag.rawValue,
            op: .isEqualTo,
            input: "DT"
        )
    )
}
