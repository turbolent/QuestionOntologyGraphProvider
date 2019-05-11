import QuestionOntology
import QuestionParser
import ParserDescription
import ParserDescriptionOperators
import Regex


final class QuestionOntologyElements<Mappings>
    where Mappings: OntologyMappings
{
    typealias Ontology = QuestionOntology<Mappings>
    typealias Token = QuestionParser.Token

    private struct ValuePropertyInstructionResult<Mappings>: Hashable
        where Mappings: OntologyMappings
    {
        let property: OntologyProperty<Mappings>
        let comparison: Comparison?
    }

    private struct ComparativePropertyInstructionResult<Mappings>: Hashable
        where Mappings: OntologyMappings
    {
        let property: OntologyProperty<Mappings>
        let comparison: Comparison
    }

    private let namedPropertyInstruction: TokenInstruction<OntologyProperty<Mappings>>
    private let inversePropertyInstruction: TokenInstruction<OntologyProperty<Mappings>>
    private let valuePropertyInstruction: TokenInstruction<ValuePropertyInstructionResult<Mappings>>
    private let adjectivePropertyInstruction: TokenInstruction<OntologyProperty<Mappings>>
    private let comparativePropertyInstruction:
        TokenInstruction<ComparativePropertyInstructionResult<Mappings>>
    private let namedClassInstruction: TokenInstruction<OntologyClass<Mappings>>

    let ontology: Ontology

    init(ontology: Ontology) throws {
        self.ontology = ontology

        namedPropertyInstruction =
            try QuestionOntologyElements
                .compilePropertyPatternInstruction(ontology: ontology) { property, propertyPattern in
                    guard case let ._named(pattern) = propertyPattern else {
                        return nil
                    }
                    return (pattern, property)
                }

        inversePropertyInstruction =
            try QuestionOntologyElements
                .compilePropertyPatternInstruction(ontology: ontology) { property, propertyPattern in
                    guard case let ._inverse(pattern) = propertyPattern else {
                        return nil
                    }
                    return (pattern, property)
                }

        valuePropertyInstruction =
            try QuestionOntologyElements
                .compilePropertyPatternInstruction(ontology: ontology) { property, propertyPattern in
                    switch propertyPattern {
                    case let ._value(pattern):
                        return (
                            pattern,
                            ValuePropertyInstructionResult(
                                property: property,
                                comparison: nil
                            )
                        )
                    case let ._comparative(pattern, comparison):
                        return (
                            pattern,
                            ValuePropertyInstructionResult(
                                property: property,
                                comparison: comparison
                            )
                        )
                    default:
                        return nil
                    }
                }

        adjectivePropertyInstruction =
            try QuestionOntologyElements
                .compilePropertyPatternInstruction(ontology: ontology) { property, propertyPattern in
                    guard case let ._adjective(pattern) = propertyPattern else {
                        return nil
                    }

                    // NOTE: prefix with be/VB
                    return (.sequence(Patterns.be ~ pattern), property)
                }

        comparativePropertyInstruction =
            try QuestionOntologyElements
                .compilePropertyPatternInstruction(ontology: ontology) { property, propertyPattern in
                    guard case let ._comparative(pattern, comparison) = propertyPattern else {
                        return nil
                    }

                return (
                    pattern,
                    ComparativePropertyInstructionResult(
                        property: property,
                        comparison: comparison
                    )
                )
            }

        namedClassInstruction =
            try QuestionOntologyElements
                .compileClassPatternInstruction(ontology: ontology) {
                    guard case let ._named(pattern) = $0 else {
                        return nil
                    }
                    return pattern
            }
    }

    private static func compilePropertyPatternInstruction<Result>(
        ontology: Ontology,
        mapping: (OntologyProperty<Mappings>, PropertyPattern) -> (AnyPattern, Result)?
    )
        throws -> TokenInstruction<Result>
        where Result: Hashable
    {
        return try compilePatternInstruction(patternsAndResults:
            ontology.properties.values.flatMap { property in
                property.patterns.compactMap { pattern in
                    mapping(property, pattern)
                }
            }
        )
    }

    private static func compileClassPatternInstruction(
        ontology: Ontology,
        filter: (ClassPattern) -> AnyPattern?
    )
        throws -> TokenInstruction<OntologyClass<Mappings>>
    {
        return try compilePatternInstruction(patternsAndResults:
            ontology.classes.values
                .flatMap { `class` in
                    `class`.patterns
                        .compactMap(filter)
                        .map { ($0, `class`) }
            }
        )
    }

    private static func compilePatternInstruction<Result>(
        patternsAndResults: [(pattern: AnyPattern, result: Result)]
    )
        throws -> TokenInstruction<Result>
        where Result: Hashable
    {
        return compile(
            instructions: try patternsAndResults
                .map { try $0.compile(result: $1) }
        )
    }

    func findNamedProperties(name: [Token])
        throws -> [OntologyProperty<Mappings>]
    {
        return namedPropertyInstruction.match(name)
    }

    func findInverseProperties(name: [Token])
        throws -> [OntologyProperty<Mappings>]
    {
        return inversePropertyInstruction.match(name)
    }

    func findAdjectiveProperties(name: [Token])
        throws -> [OntologyProperty<Mappings>]
    {
        return adjectivePropertyInstruction.match(name)
    }

    func findValueProperties(name: [Token])
        throws -> [(property: OntologyProperty<Mappings>, comparison: Comparison?)]
    {
        return valuePropertyInstruction.match(name)
            .map { result in
                (result.property, result.comparison)
            }
    }

    func findComparativeProperties(name: [Token])
        throws -> [(property: OntologyProperty<Mappings>, comparison: Comparison)]
    {
        return comparativePropertyInstruction.match(name)
            .map { result in
                (result.property, result.comparison)
            }
    }

    func findNamedClasses(name: [Token])
        throws -> [OntologyClass<Mappings>]
    {
        return namedClassInstruction.match(name)
    }
}
