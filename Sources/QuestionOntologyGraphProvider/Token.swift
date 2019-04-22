import QuestionParser
import QuestionOntology
import Regex


extension QuestionParser.Token: Regex.Token {
    public func value(forTokenLabel label: String) -> String {
        switch Label(rawValue: label) {
        case .fineTag?:
            return tag
        case .broadTag?:
            return String(tag.first ?? Character(""))
        case .lemma?:
            return lemma
        default:
            // TODO:
            fatalError("unsupported token label: \(label)")
        }
    }
}
