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

    private struct ValuePropertyInstructionResult: Hashable {
        let propertyIdentifier: String
        let comparison: Comparison?
    }

    private struct ComparativePropertyInstructionResult: Hashable {
        let propertyIdentifier: String
        let comparison: Comparison
    }

    private let namedPropertyInstruction: TokenInstruction<String>
    private let inversePropertyInstruction: TokenInstruction<String>
    private let valuePropertyInstruction: TokenInstruction<ValuePropertyInstructionResult>
    private let adjectivePropertyInstruction: TokenInstruction<String>
    private let comparativePropertyInstruction: TokenInstruction<ComparativePropertyInstructionResult>
    private let namedClassInstruction: TokenInstruction<String>

    let ontology: Ontology

    init(ontology: Ontology) throws {
        self.ontology = ontology

        namedPropertyInstruction =
            try QuestionOntologyElements
                .compilePropertyPatternInstruction(ontology: ontology) { property, propertyPattern in
                    guard case let ._named(pattern) = propertyPattern else {
                        return nil
                    }
                    return (pattern, property.identifier)
                }

        inversePropertyInstruction =
            try QuestionOntologyElements
                .compilePropertyPatternInstruction(ontology: ontology) { property, propertyPattern in
                    guard case let ._inverse(pattern) = propertyPattern else {
                        return nil
                    }
                    return (pattern, property.identifier)
                }

        valuePropertyInstruction =
            try QuestionOntologyElements
                .compilePropertyPatternInstruction(ontology: ontology) { property, propertyPattern in
                    switch propertyPattern {
                    case let ._value(pattern):
                        return (
                            pattern,
                            ValuePropertyInstructionResult(
                                propertyIdentifier: property.identifier,
                                comparison: nil
                            )
                        )
                    case let ._comparative(pattern, comparison):
                        return (
                            pattern,
                            ValuePropertyInstructionResult(
                                propertyIdentifier: property.identifier,
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
                    return (.sequence(Patterns.be ~ pattern), property.identifier)
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
                        propertyIdentifier: property.identifier,
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
        throws -> TokenInstruction<String>
    {
        return try compilePatternInstruction(patternsAndResults:
            ontology.classes.values
                .flatMap { `class` in
                    `class`.patterns
                        .compactMap(filter)
                        .map { ($0, `class`.identifier) }
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

    private func findProperties(identifiers: [String])
        throws -> [OntologyProperty<Mappings>]
    {
        return try identifiers.map {
            guard let property = ontology.properties[$0] else {
                throw Error.notAvailable
            }
            return property
        }
    }

    private func findClasses(identifiers: [String])
        throws -> [OntologyClass<Mappings>]
    {
        return try identifiers.map {
            guard let `class` = ontology.classes[$0] else {
                throw Error.notAvailable
            }
            return `class`
        }
    }

    func findNamedProperties(name: [Token])
        throws -> [OntologyProperty<Mappings>]
    {
        return try findProperties(
            identifiers: namedPropertyInstruction.match(name)
        )
    }

    func findInverseProperties(name: [Token])
        throws -> [OntologyProperty<Mappings>]
    {
        return try findProperties(
            identifiers: inversePropertyInstruction.match(name)
        )
    }

    func findAdjectiveProperties(name: [Token])
        throws -> [OntologyProperty<Mappings>]
    {
        return try findProperties(
            identifiers: adjectivePropertyInstruction.match(name)
        )
    }

    func findValueProperties(name: [Token])
        throws -> [(property: OntologyProperty<Mappings>, comparison: Comparison?)]
    {
        let results = valuePropertyInstruction.match(name)

        return try results.map { result in
            guard let property = ontology.properties[result.propertyIdentifier] else {
                throw Error.notAvailable
            }
            return (property, result.comparison)
        }
    }

    func findComparativeProperties(name: [Token])
        throws -> [(property: OntologyProperty<Mappings>, comparison: Comparison)]
    {
        let results = comparativePropertyInstruction.match(name)

        return try results.map { result in
            guard let property = ontology.properties[result.propertyIdentifier] else {
                throw Error.notAvailable
            }
            return (property, result.comparison)
        }
    }

    func findNamedClasses(name: [Token])
        throws -> [OntologyClass<Mappings>]
    {
        return try findClasses(
            identifiers: namedClassInstruction.match(name)
        )
    }
}
